-- PART D: Analysis: 
-- Question 1: Visualize the number of volunteers available by city (according to their
-- volunteer range, note: a volunteer can be available in more than 1 city)
-- compared to the number of volunteers that applied for a request in that city.
-- What’s the city with the most (top 2) volunteers and the least (bottom 2)?
-- Make sure your visualization gives a good overview of the current situation
-- and quickly shows the most information.

SELECT 
    COALESCE(av.name, ap.name) AS city_name, 
    COALESCE(av.available_volunteers, 0) AS available_volunteers,
    COALESCE(ap.applied_volunteers, 0) AS applied_volunteers
FROM (
    SELECT c.name, COUNT(DISTINCT vr.volunteer_id) AS available_volunteers
    FROM Volunteer_Range vr
    JOIN City c ON vr.city_id = c.id
    GROUP BY c.name
) av
FULL OUTER JOIN (
    SELECT c.name, COUNT(DISTINCT a.volunteer_id) AS applied_volunteers
    FROM Application a
    JOIN Request_Location rl ON a.request_id = rl.request_id
    JOIN City c ON rl.city_id = c.id
    WHERE a.is_valid = TRUE
    GROUP BY c.name
) ap
ON av.name = ap.name
ORDER BY available_volunteers DESC, applied_volunteers DESC;

-- Question 2: Create your own scoring system to calculate the matching percentage
-- from all the attributes of a volunteer that you find relevant: e.g: interest, travel
-- readiness, volunteer range, number of skill matches, etc. Make a compelling
-- case for your scoring scheme and suggest a top 5 candidates for each
-- request according to this system. 

-- Step 1: Calculate Skills Match Score
WITH SkillsMatchScore AS (
    SELECT
        vs.volunteer_id,
        rs.request_id,
        (COUNT(vs.skill_name) / (SELECT COUNT(*) FROM Request_Skill WHERE request_id = rs.request_id)) * 40 AS skills_match_score
    FROM Volunteer_Skill vs
    JOIN Request_Skill rs ON vs.skill_name = rs.skill_name
    GROUP BY vs.volunteer_id, rs.request_id
),

-- Step 2: Calculate Travel Readiness Score
TravelReadinessScore AS (
    SELECT 
        v.id AS volunteer_id,
        (v.travel_readiness / 5.0) * 30 AS travel_readiness_score
    FROM Volunteer v
),

-- Step 3: Calculate Volunteer Range Score
VolunteerRangeScore AS (
    SELECT
        vr.volunteer_id,
        rl.request_id,
        CASE 
            WHEN vr.city_id = rl.city_id THEN 20
            ELSE 0
        END AS volunteer_range_score
    FROM Volunteer_Range vr
    JOIN Request_Location rl ON vr.city_id = rl.city_id
),

-- Step 4: Calculate Areas of Interest Score
AreasOfInterestScore AS (
    SELECT
        vai.volunteer_id,
        r.id as request_id,
        (COUNT(vai.interest_name) / (SELECT COUNT(*) FROM Volunteer_Area_Of_Interest WHERE volunteer_id = vai.volunteer_id)) * 10 AS areas_of_interest_score
    FROM Volunteer_Area_Of_Interest vai
    JOIN Request r ON vai.interest_name = r.title
    GROUP BY vai.volunteer_id, r.id
),

-- Step 5: Combine All Scores to Calculate Match Percentage
MatchPercentage AS (
    SELECT
        tr.volunteer_id,
        sm.request_id,
        (tr.travel_readiness_score + sm.skills_match_score + vr.volunteer_range_score + ai.areas_of_interest_score) AS match_percentage
    FROM TravelReadinessScore tr
    JOIN SkillsMatchScore sm ON tr.volunteer_id = sm.volunteer_id
    JOIN VolunteerRangeScore vr ON sm.volunteer_id = vr.volunteer_id AND sm.request_id = vr.request_id
    JOIN AreasOfInterestScore ai ON sm.volunteer_id = ai.volunteer_id AND sm.request_id = ai.request_id
)

-- Step 6: Suggest Top 5 Candidates for Each Request
SELECT
    request_id,
    volunteer_id,
    match_percentage
FROM (
    SELECT
        request_id,
        volunteer_id,
        match_percentage,
        ROW_NUMBER() OVER (PARTITION BY request_id ORDER BY match_percentage DESC) AS rank
    FROM MatchPercentage
) ranked
WHERE rank <= 5
ORDER BY request_id, match_percentage DESC;


-- Question 3: For each month, what are the number of valid volunteer applications
-- compared to the number of valid requests? What months have the most and
-- least for each, how about the difference between the requests and
-- volunteers for each month? Is there a general/seasonal trend? Is there any
-- correlation between the time of the year and number of requests and
-- volunteers? See analysis.py.

WITH ValidApplications AS (
    SELECT
        request_id,
        volunteer_id,
        time_modified,
        EXTRACT(YEAR FROM time_modified) AS year,
        EXTRACT(MONTH FROM time_modified) AS month
    FROM Application
    WHERE is_valid = TRUE
),
ValidRequests AS (
    SELECT
        id AS request_id,
        start_date,
        EXTRACT(YEAR FROM start_date) AS year,
        EXTRACT(MONTH FROM start_date) AS month
    FROM Request
    WHERE start_date IS NOT NULL
)
SELECT
    va.year,
    va.month,
    va.valid_applications,
    vr.valid_requests,
    (va.valid_applications - vr.valid_requests) AS difference
FROM (
    SELECT
        year,
        month,
        COUNT(*) AS valid_applications
    FROM ValidApplications
    GROUP BY year, month
) va
JOIN (
    SELECT
        year,
        month,
        COUNT(*) AS valid_requests
    FROM ValidRequests
    GROUP BY year, month
) vr
ON va.year = vr.year AND va.month = vr.month
ORDER BY va.year, va.month;



-- Question 4: Free choice
-- Does the number of skills a volunteer has affect the chance of their application
-- being accepted? See analysis.py.
SELECT v.id AS volunteer_id, COALESCE(vs.skill_count, 0) AS skill_count, COALESCE(sa.successful_applications, 0) AS successful_applications
FROM Volunteer v
LEFT JOIN (
    SELECT vs.volunteer_id, COUNT(vs.skill_name) AS skill_count
    FROM Volunteer_Skill vs
    GROUP BY vs.volunteer_id
) vs ON v.id = vs.volunteer_id
LEFT JOIN (
    SELECT a.volunteer_id, COUNT(a.id) AS successful_applications
    FROM Application a
    WHERE a.is_valid = TRUE
    GROUP BY a.volunteer_id
) sa ON v.id = sa.volunteer_id;