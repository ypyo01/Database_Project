-- Drop and recreate the Beneficiary table
DROP TABLE IF EXISTS Beneficiary;
CREATE TABLE Beneficiary (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    address TEXT NOT NULL
);

-- Drop and recreate the City table
DROP TABLE IF EXISTS City;
CREATE TABLE City (
    id INT PRIMARY KEY,
    name TEXT NOT NULL,
    latitude FLOAT NOT NULL, 
    longitude FLOAT NOT NULL 
);

-- Drop and recreate the Skills table
DROP TABLE IF EXISTS Skill;
CREATE TABLE Skill (
    name TEXT PRIMARY KEY,
    description TEXT NOT NULL
);

-- Drop and recreate the Volunteer table
DROP TABLE IF EXISTS Volunteer;
CREATE TABLE Volunteer (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    birthdate DATE NOT NULL,
    email TEXT NOT NULL,
    address TEXT NOT NULL,
    travel_readiness INT NOT NULL 
);

-- Drop and recreate the Request table
DROP TABLE IF EXISTS Request;
CREATE TABLE Request (
    id INT PRIMARY KEY,
    title TEXT NOT NULL,
    beneficiary_id TEXT,
    number_of_volunteers INT NOT NULL,
    priority_value INT NOT NULL CHECK (priority_value BETWEEN 0 AND 5),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    register_by_date DATE NOT NULL
);

-- Drop and recreate the RequestSkill table
DROP TABLE IF EXISTS Request_Skill;
CREATE TABLE Request_Skill (
    request_id INT NOT NULL,
    skill_name TEXT NOT NULL,
    min_need INT NOT NULL,
    importance INT NOT NULL CHECK (importance BETWEEN 0 AND 5),
    PRIMARY KEY (request_id, skill_name)
);

-- Drop and recreate the RequestLocation table
DROP TABLE IF EXISTS Request_Location;
CREATE TABLE Request_Location (
    request_id INT,
    city_id INT,
    PRIMARY KEY (request_id, city_id)
);

-- Drop and recreate the VolunteerAreasOfInterest table
DROP TABLE IF EXISTS Volunteer_Area_Of_Interest;
CREATE TABLE Volunteer_Area_Of_Interest (
    volunteer_id TEXT,
    interest_name TEXT,
    PRIMARY KEY (volunteer_id, interest_name)
);

-- Drop and recreate the VolunteerSkill table
DROP TABLE IF EXISTS Volunteer_Skill;
CREATE TABLE Volunteer_Skill (
    volunteer_id TEXT,
    skill_name TEXT,
    PRIMARY KEY (volunteer_id, skill_name)
);

-- Drop and recreate the Application table
DROP TABLE IF EXISTS Application;
CREATE TABLE Application (
    id INT PRIMARY KEY,
    request_id INT NOT NULL,
    volunteer_id TEXT NOT NULL,
    time_modified TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_valid BOOLEAN NOT NULL
);

-- Drop and recreate the VolunteerRange table
DROP TABLE IF EXISTS Volunteer_Range;
CREATE TABLE Volunteer_Range (
    volunteer_id TEXT,
    city_id INT,
    PRIMARY KEY (volunteer_id, city_id)
);

