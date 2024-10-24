-- Transactions
-- C: Creating a transaction that will read valid applications for a request
DROP TABLE IF EXISTS volunteer_assignment;
CREATE TABLE volunteer_assignment (
    request_id INT,
    volunteer_id TEXT,
    PRIMARY KEY (request_id, volunteer_id),
    FOREIGN KEY (request_id) REFERENCES Request(id),
    FOREIGN KEY (volunteer_id) REFERENCES Volunteer(id)
);

DO $$
DECLARE
    v_request_id INT := 1;  -- Set the request ID you want to process
    min_volunteers_needed INT;
    reg_by_date DATE;
    volunteer_count INT;
    transaction_result TEXT;
BEGIN
    -- Fetch the request details
    SELECT number_of_volunteers, register_by_date INTO min_volunteers_needed, reg_by_date
    FROM Request
    WHERE id = v_request_id;

    -- Fetch valid applications for the given request and prioritize them
    WITH valid_applications AS (
        SELECT 
            A.id AS application_id,
            A.volunteer_id,
            V.travel_readiness,
            VS.skill_name,
            RS.importance,
            RS.min_need,
            ROW_NUMBER() OVER (PARTITION BY RS.skill_name ORDER BY RS.importance DESC, V.travel_readiness DESC) AS skill_rank
        FROM Application A
        JOIN Volunteer V ON A.volunteer_id = V.id
        JOIN Volunteer_Skill VS ON V.id = VS.volunteer_id
        JOIN Request_Skill RS ON A.request_id = RS.request_id AND VS.skill_name = RS.skill_name
        WHERE A.request_id = v_request_id AND A.is_valid = TRUE
    ),
    prioritized_skill_volunteers AS (
        SELECT 
            v_request_id AS request_id,
            volunteer_id,
            skill_name,
            min_need,
            ROW_NUMBER() OVER (PARTITION BY skill_name ORDER BY importance DESC, travel_readiness DESC) AS overall_rank
        FROM valid_applications
    )
    -- Assigning volunteers with valid applications
    INSERT INTO volunteer_assignment (request_id, volunteer_id)
    SELECT 
        request_id,
        volunteer_id
    FROM prioritized_skill_volunteers
    WHERE overall_rank <= min_need
    ON CONFLICT DO NOTHING;

    -- Count the assigned volunteers
    SELECT COUNT(*) INTO volunteer_count
    FROM volunteer_assignment
    WHERE request_id = v_request_id;

    -- Determine transaction result
    IF volunteer_count >= min_volunteers_needed THEN
        transaction_result := 'Commit';
    ELSE
        IF CURRENT_DATE < reg_by_date THEN
            transaction_result := 'Rollback';
        ELSE
            transaction_result := 'Extend Registration';
        END IF;
    END IF;

    -- Execute the transaction result
    IF transaction_result = 'Commit' THEN
        COMMIT;
        RAISE NOTICE 'Transaction committed: Sufficient volunteers assigned.';
    ELSIF transaction_result = 'Rollback' THEN
        ROLLBACK;
        RAISE NOTICE 'Transaction rolled back: Insufficient volunteers, registration still open.';
    ELSE
        UPDATE Request
        SET register_by_date = CURRENT_DATE + INTERVAL '7 days'
        WHERE id = v_request_id;
        COMMIT;
        RAISE NOTICE 'Transaction committed: Registration date extended by 7 days due to insufficient volunteers.';
    END IF;
END $$;


-- Creating a transaction of our own choice
DROP TABLE IF EXISTS volunteer_changes;
CREATE TABLE volunteer_changes (
    id SERIAL PRIMARY KEY,
    volunteer_id TEXT NOT NULL,
    old_address TEXT NOT NULL,
    new_address TEXT NOT NULL,
    change_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DO $$
DECLARE
    v_id TEXT := '011095-974M';  -- The ID of the volunteer to update
    new_addr TEXT := 'Otakaari 1, Espoo';  -- The new address
    old_addr TEXT;
BEGIN
    -- Fetch the current address of the volunteer
    SELECT address INTO old_addr
    FROM Volunteer
    WHERE id = v_id;

    -- Update the volunteer's address
    UPDATE Volunteer
    SET address = new_addr
    WHERE id = v_id;

    -- Log the change in the volunteer_changes table
    INSERT INTO volunteer_changes (volunteer_id, old_address, new_address)
    VALUES (v_id, old_addr, new_addr);

    RAISE NOTICE 'Volunteer address updated and change logged successfully.';
EXCEPTION
    WHEN OTHERS THEN
        -- Handle the exception
        RAISE NOTICE 'Transaction failed: %', SQLERRM;
END $$;
