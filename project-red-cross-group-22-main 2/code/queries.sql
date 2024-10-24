--PART A: BASIC
--QUESTION 1: For each request, include the starting date and the end date in the title.
SELECT id, 
       title || ' (' || start_date::text || ' to ' || end_date::text || ')' AS updated_title, 
       start_date, 
       end_date 
FROM Request;


--QUESTION 2: For each request, find volunteers whose skill assignments match the
--requesting skills. List these volunteers from those with the most matching
--skills to those with the least (even 0 matching skills). Only consider
--volunteers who applied to the request and have a valid application
SELECT r.id AS request_id, 
       r.title,
       r.start_date,
       r.end_date,
       v.id AS volunteer_id,
       v.name AS volunteer_name,
       COUNT(vs.skill_name) AS matching_skills
FROM Request r
JOIN Application a ON r.id = a.request_id
JOIN Volunteer v ON a.volunteer_id = v.id
LEFT JOIN Request_Skill rs ON r.id = rs.request_id
LEFT JOIN Volunteer_Skill vs ON v.id = vs.volunteer_id AND rs.skill_name = vs.skill_name
WHERE a.is_valid = TRUE
GROUP BY r.id, r.title, r.start_date, r.end_date, v.id, v.name
ORDER BY r.id, matching_skills DESC, v.id;


--QUESTION 3: For each request, show the missing number of volunteers needed per
--skill (minimum needed of that skill). Assume a volunteer fulfills the need for all
--the skills they possess.
WITH RequestSkillCount AS (
    SELECT rs.request_id,
           rs.skill_name,
           rs.min_need,
           COUNT(DISTINCT CASE WHEN a.is_valid = TRUE AND rs.skill_name = vs.skill_name THEN a.volunteer_id END) AS current_count
    FROM Request_Skill rs
    LEFT JOIN Application a ON rs.request_id = a.request_id
    LEFT JOIN Volunteer_Skill vs ON a.volunteer_id = vs.volunteer_id
    GROUP BY rs.request_id, rs.skill_name, rs.min_need
)
SELECT request_id,
       skill_name,
       min_need,
       current_count,
       (min_need - current_count) AS missing_volunteers
FROM RequestSkillCount;


--QUESTION 4: Sort requests and the beneficiaries who made them by the highest
--number of priority (request’s priority value) and the closest 'register by date'.
SELECT 
    r.id AS request_id, 
    r.title AS request_title, 
    b.id AS beneficiary_id, 
    b.name AS beneficiary_name, 
    r.priority_value, 
    r.register_by_date
FROM 
    Request r
JOIN 
    Beneficiary b ON r.beneficiary_id = b.id
ORDER BY 
    r.priority_value DESC, 
    ABS(EXTRACT(EPOCH FROM (r.register_by_date::timestamp - CURRENT_DATE::timestamp))), 
    r.register_by_date;


--QUESTION 5: For each volunteer, list requests that are within their volunteer range and
--match at least 2 of their skills (also include requests that don’t require any
--skills)
SELECT 
    v.id AS volunteer_id, 
    r.id AS request_id, 
    r.title AS request_title
FROM 
    Volunteer v
JOIN 
    Volunteer_Range vr ON v.id = vr.volunteer_id
JOIN 
    Request_Location rl ON vr.city_id = rl.city_id
JOIN 
    Request r ON r.id = rl.request_id
LEFT JOIN (
    SELECT 
        rs.request_id, 
        COUNT(vs.skill_name) AS matching_skills,
        vs.volunteer_id AS volunteer_id
    FROM 
        Request_Skill rs
    JOIN 
        Volunteer_Skill vs ON rs.skill_name = vs.skill_name
    GROUP BY 
        rs.request_id, 
        vs.volunteer_id
) AS matching_skills_count ON r.id = matching_skills_count.request_id AND matching_skills_count.volunteer_id = v.id
WHERE 
    (matching_skills_count.matching_skills >= 2 OR matching_skills_count.matching_skills IS NULL)
    AND r.start_date >= CURRENT_DATE
ORDER BY 
    v.id, 
    r.id;


--QUESTION 6:For each volunteer, list all the requests where the title matches their area
--of interest and are still available to register
SELECT v.id AS volunteer_id, r.id AS request_id, r.title AS request_title
FROM Volunteer v
JOIN Volunteer_Area_Of_Interest vai ON v.id = vai.volunteer_id
JOIN Request r ON r.title = vai.interest_name
WHERE r.register_by_date::timestamp >= CURRENT_DATE::timestamp;

--QUSTION 7: List the request ID and the volunteers who applied to them (name and email) 
--but are not within the location range of the request. Order volunteers
--by readiness to travel
SELECT 
    r.id AS request_id,
    v.name AS volunteer_name,
    v.email AS volunteer_email
FROM Application a
JOIN Request r ON a.request_id = r.id
JOIN Volunteer v ON a.volunteer_id = v.id
JOIN Request_Location rl ON r.id = rl.request_id
LEFT JOIN Volunteer_Range vr ON v.id = vr.volunteer_id AND rl.city_id = vr.city_id
WHERE vr.city_id IS NULL
ORDER BY 
    v.travel_readiness DESC;

-- QUESTION 8: Order the skills overall (from all requests) in the most prioritized to least
-- prioritized (average the importance value).
SELECT
    skill_name,
    AVG(importance) AS average_importance
FROM Request_Skill
GROUP BY skill_name
ORDER BY average_importance DESC;

-- QUESTION 9 to 12: Construct 4 queries of your choice and explain
-- why these are important for the VMS.

-- QUESTION 9: Let's assume that Finnish Red Cross want to grant
-- a certificate for active volunteers.
-- Thus, the query counts the number of valid application of identical volunteer
-- who made more than 15 applications and list them in descending order.
SELECT
    volunteer_id,
    COUNT(*) AS valid_application_count
FROM Application
WHERE is_valid = TRUE
GROUP BY volunteer_id
HAVING COUNT(*) > 15
ORDER BY
    valid_application_count DESC;

-- QUESTION 10: Find volunteers with more diverse skills than others. 
-- Volunteers with more skills can do multiple role, which means many requests can be matched to them.
-- Matching process could be more flexible by matching volunteers with less skills first to their right request and the rest later.
SELECT
    vs.volunteer_id,
    v.name AS volunteer_name,
    COUNT(DISTINCT vs.skill_name) AS skill_count
FROM Volunteer_Skill vs
JOIN Volunteer v ON vs.volunteer_id = v.id
GROUP BY vs.volunteer_id, v.name
ORDER BY
    skill_count DESC;

-- QUESTION 11: Identify overlapping volunteer commitments
-- This query identifies volunteers who have overlapping commitments, 
-- i.e., they have applied for multiple requests that have overlapping dates. 
-- This is important to ensure that volunteers are not overcommitting and can fulfill their obligations.
SELECT
    v.id AS volunteer_id,
    v.name AS volunteer_name,
    r1.id AS request_id_1,
    r1.title AS request_title_1,
    r1.start_date AS start_date_1,
    r1.end_date AS end_date_1,
    r2.id AS request_id_2,
    r2.title AS request_title_2,
    r2.start_date AS start_date_2,
    r2.end_date AS end_date_2
FROM Application a1
JOIN Request r1 ON a1.request_id = r1.id
JOIN Application a2 ON a1.volunteer_id = a2.volunteer_id
JOIN Request r2 ON a2.request_id = r2.id
JOIN Volunteer v ON a1.volunteer_id = v.id
WHERE
    a1.is_valid = TRUE
    AND a2.is_valid = TRUE
    AND r1.id <> r2.id
    AND r1.start_date <= r2.end_date
    AND r1.end_date >= r2.start_date
ORDER BY
    v.id, r1.start_date;

-- QUESTION 12: Find requests with insufficient applications
-- This query identifies requests that have not received the required number of volunteer applications. 
-- This is important for ensuring that all requests have enough volunteers 
-- to be fulfilled and to take action on requests that may be under-resourced.
SELECT
    r.id AS request_id,
    r.title AS request_title,
    r.nov AS number_of_volunteers,
    COUNT(a.id) AS application_count
FROM Request r
LEFT JOIN Application a ON r.id = a.request_id AND a.is_valid = TRUE
GROUP BY r.id, r.title, r.nov
HAVING COUNT(a.id) < r.nov
ORDER BY
    application_count ASC;

--PART B: ADVANCED
-- A Question 1: Create a view that lists next to each beneficiary the average number of
-- volunteers that applied, the average age that applied, and the average
-- number of volunteers they need across all of their requests.

CREATE VIEW Beneficiary_Statistics AS
SELECT
    b.id AS beneficiary_id,
    b.name AS beneficiary_name,
    AVG(CAST(COALESCE(vr.number_of_volunteers, 0) AS FLOAT)) AS avg_applied_volunteers,
    AVG(EXTRACT(YEAR FROM AGE(v.birthdate))) AS avg_age_applied_volunteers,
    AVG(CAST(r.number_of_volunteers AS FLOAT)) AS avg_number_of_volunteers_needed
FROM
    Beneficiary b
LEFT JOIN
    Request r ON b.id = r.beneficiary_id
LEFT JOIN
    Application a ON r.id = a.request_id
LEFT JOIN
    Volunteer v ON a.volunteer_id = v.id
LEFT JOIN
    (
        SELECT
            request_id,
            COUNT(*) AS number_of_volunteers
        FROM
            Application
        GROUP BY
            request_id
    ) vr ON r.id = vr.request_id
GROUP BY
    b.id, b.name;

-- A Question 2: Create a view of your own choice 
-- View to visualize how many volunteers have applied to each
-- request and percentage of capacity can be fulfilled through 
-- the current pool.

CREATE VIEW Request_overview AS
SELECT
    r.id AS request_id,
    r.title AS request_title,
    COUNT(DISTINCT a.volunteer_id) AS applied_volunteers,
    r.number_of_volunteers AS total_volunteers_needed,
    CASE
        WHEN r.number_of_volunteers > 0 THEN
            ROUND(CAST(COUNT(DISTINCT a.volunteer_id) AS NUMERIC) / r.number_of_volunteers * 100, 2)
        ELSE
            0
    END AS percentage_applied
FROM
    Request r
LEFT JOIN
    Application a ON r.id = a.request_id
GROUP BY
    r.id, r.title, r.number_of_volunteers;

-- B Question 1: Create a check constraint for the volunteer table with a function that
-- validates a volunteer ID when a new volunteer is inserted. 

-- Create the validation function
CREATE OR REPLACE FUNCTION validate_finnish_id(id TEXT) RETURNS BOOLEAN AS $$
DECLARE
    birthdate_part TEXT;
    individual_part TEXT;
    control_character TEXT;
    nine_digit_number BIGINT;
    expected_control_character CHAR;
    remainder INT;
    control_characters TEXT := '0123456789ABCDEFHJKLMNPRSTUVWXY';
BEGIN
    -- Check the length
    IF LENGTH(id) <> 11 THEN
        RETURN FALSE;
    END IF;

    -- Check the separator character
    IF SUBSTRING(id FROM 7 FOR 1) NOT IN ('+', '-', 'A', 'B', 'C', 'D', 'E', 'F', 'X', 'Y', 'W', 'V', 'U') THEN
        RETURN FALSE;
    END IF;

    -- Extract parts of the ID
    birthdate_part := SUBSTRING(id FROM 1 FOR 6);
    individual_part := SUBSTRING(id FROM 8 FOR 3);
    control_character := SUBSTRING(id FROM 11 FOR 1);

    -- Combine to form the nine-digit number
    nine_digit_number := CAST(birthdate_part || individual_part AS BIGINT);

    -- Calculate the remainder
    remainder := nine_digit_number % 31;

    -- Get the expected control character
    expected_control_character := SUBSTRING(control_characters FROM remainder + 1 FOR 1);

    -- Compare the provided control character with the expected one
    IF control_character = expected_control_character THEN
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

ALTER TABLE Volunteer
ADD CONSTRAINT valid_finnish_id CHECK (validate_finnish_id(id));

-- B Question 2:  Create a trigger that updates the number of volunteers for a request
-- whenever the minimum need for any of its skill requirements is changed.

CREATE OR REPLACE FUNCTION update_volunteer_count() 
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate the total number of volunteers needed for the request
    UPDATE Request
    SET number_of_volunteers = COALESCE(
        (SELECT SUM(min_need)
         FROM Request_Skill
         WHERE request_id = NEW.request_id), 0)
    WHERE id = NEW.request_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER UpdateVolunteerCountTriggerUpdate
AFTER UPDATE ON Request_Skill
FOR EACH ROW
EXECUTE FUNCTION update_volunteer_count();


--TRIGGERS
-- Create the trigger function to check for max application per volunteer
-- Check if the trigger exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'application_insert_trigger'
    ) THEN
        -- Drop the trigger if it exists
        DROP TRIGGER application_insert_trigger ON Application;
    END IF;
END $$;

-- Create or replace the trigger function
CREATE OR REPLACE FUNCTION check_volunteer_applications()
RETURNS TRIGGER AS $$
BEGIN
    -- Check the count of applications for the volunteer
    IF (SELECT COUNT(*) FROM Application WHERE volunteer_id = NEW.volunteer_id) >= 20 THEN
        -- Raise an exception if there are already 20 or more applications
        RAISE EXCEPTION 'A volunteer cannot have more than 20 applications';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER application_insert_trigger
BEFORE INSERT ON Application
FOR EACH ROW
EXECUTE FUNCTION check_volunteer_applications();
