-- ################################################################################
-- # PARTIE 1 - FRAGMENTATION HORIZONTALE
-- ################################################################################

-- ================================================================================
-- >>> CONNEXION : admin_xepdb1
-- ================================================================================
CREATE USER north_user IDENTIFIED BY north_pass;
GRANT CONNECT, RESOURCE TO north_user;
ALTER USER north_user QUOTA UNLIMITED ON users;

CREATE USER south_user IDENTIFIED BY south_pass;
GRANT CONNECT, RESOURCE TO south_user;
ALTER USER south_user QUOTA UNLIMITED ON users;

CREATE USER east_user IDENTIFIED BY east_pass;
GRANT CONNECT, RESOURCE TO east_user;
ALTER USER east_user QUOTA UNLIMITED ON users;


-- ================================================================================
-- >>> CONNEXION : north
-- ================================================================================
CREATE TABLE Trips (
  TripID NUMBER PRIMARY KEY,
  Region NVARCHAR2(50),
  StartDate DATE,
  EndDate DATE
);
INSERT INTO Trips VALUES (101, 'North', TO_DATE('2025-06-01','YYYY-MM-DD'), TO_DATE('2025-06-10','YYYY-MM-DD'));
INSERT INTO Trips VALUES (104, 'North', TO_DATE('2025-06-15','YYYY-MM-DD'), TO_DATE('2025-06-25','YYYY-MM-DD'));
INSERT INTO Trips VALUES (107, 'North', TO_DATE('2025-07-01','YYYY-MM-DD'), TO_DATE('2025-07-07','YYYY-MM-DD'));

CREATE TABLE Guides (
  GuideID NUMBER PRIMARY KEY,
  Name NVARCHAR2(100),
  Region NVARCHAR2(50),
  Languages NVARCHAR2(100)
);
INSERT INTO Guides VALUES (304, 'Pierre Dubois', 'North', 'French, Spanish');
INSERT INTO Guides VALUES (305, 'Marie Lefevre', 'North', 'French, English, German');
INSERT INTO Guides VALUES (306, 'Lucas Fournier', 'North', 'French, Arabic');

CREATE TABLE Accommodations (
  HotelID NUMBER PRIMARY KEY,
  Name NVARCHAR2(100),
  Region NVARCHAR2(50),
  Rating NUMBER
);
INSERT INTO Accommodations VALUES (501, 'Hotel du Nord', 'North', 4);
INSERT INTO Accommodations VALUES (502, 'Normandy Lodge', 'North', 3);

CREATE TABLE CulturalEvents (
  EventID NUMBER PRIMARY KEY,
  Region NVARCHAR2(50),
  Name NVARCHAR2(100),
  EventDate DATE,
  EventType NVARCHAR2(50)
);
INSERT INTO CulturalEvents VALUES (404, 'North', 'Paris Jazz Festival', TO_DATE('2025-06-05','YYYY-MM-DD'), 'Cultural');
INSERT INTO CulturalEvents VALUES (405, 'North', 'D-Day Commemoration', TO_DATE('2025-06-06','YYYY-MM-DD'), 'Historical');

COMMIT;


-- ================================================================================
-- >>> CONNEXION : south
-- ================================================================================
CREATE TABLE Trips (
  TripID NUMBER PRIMARY KEY,
  Region NVARCHAR2(50),
  StartDate DATE,
  EndDate DATE
);
INSERT INTO Trips VALUES (102, 'South', TO_DATE('2025-07-05','YYYY-MM-DD'), TO_DATE('2025-07-15','YYYY-MM-DD'));
INSERT INTO Trips VALUES (105, 'South', TO_DATE('2025-07-20','YYYY-MM-DD'), TO_DATE('2025-07-30','YYYY-MM-DD'));
INSERT INTO Trips VALUES (108, 'South', TO_DATE('2025-08-05','YYYY-MM-DD'), TO_DATE('2025-08-12','YYYY-MM-DD'));

CREATE TABLE Guides (
  GuideID NUMBER PRIMARY KEY,
  Name NVARCHAR2(100),
  Region NVARCHAR2(50),
  Languages NVARCHAR2(100)
);
INSERT INTO Guides VALUES (301, 'Jean Leclerc', 'South', 'French, English');
INSERT INTO Guides VALUES (307, 'Camille Dubois', 'South', 'French, Italian');

CREATE TABLE Accommodations (
  HotelID NUMBER PRIMARY KEY,
  Name NVARCHAR2(100),
  Region NVARCHAR2(50),
  Rating NUMBER
);
INSERT INTO Accommodations VALUES (503, 'Le Vieux Port', 'South', 5);

CREATE TABLE CulturalEvents (
  EventID NUMBER PRIMARY KEY,
  Region NVARCHAR2(50),
  Name NVARCHAR2(100),
  EventDate DATE,
  EventType NVARCHAR2(50)
);
INSERT INTO CulturalEvents VALUES (406, 'South', 'Nice Carnival', TO_DATE('2025-07-25','YYYY-MM-DD'), 'Cultural');

COMMIT;


-- ================================================================================
-- >>> CONNEXION : east
-- ================================================================================
CREATE TABLE Trips (
  TripID NUMBER PRIMARY KEY,
  Region NVARCHAR2(50),
  StartDate DATE,
  EndDate DATE
);
INSERT INTO Trips VALUES (103, 'East', TO_DATE('2025-08-01','YYYY-MM-DD'), TO_DATE('2025-08-10','YYYY-MM-DD'));
INSERT INTO Trips VALUES (106, 'East', TO_DATE('2025-08-15','YYYY-MM-DD'), TO_DATE('2025-08-25','YYYY-MM-DD'));
INSERT INTO Trips VALUES (109, 'East', TO_DATE('2025-09-01','YYYY-MM-DD'), TO_DATE('2025-09-07','YYYY-MM-DD'));

CREATE TABLE Guides (
  GuideID NUMBER PRIMARY KEY,
  Name NVARCHAR2(100),
  Region NVARCHAR2(50),
  Languages NVARCHAR2(100)
);
INSERT INTO Guides VALUES (302, 'Sophie Blanc', 'East', 'French, German');
INSERT INTO Guides VALUES (303, 'Antoine Giraud', 'East', 'French, English');

CREATE TABLE Accommodations (
  HotelID NUMBER PRIMARY KEY,
  Name NVARCHAR2(100),
  Region NVARCHAR2(50),
  Rating NUMBER
);
INSERT INTO Accommodations VALUES (504, 'Lyon City Hotel', 'East', 4);
INSERT INTO Accommodations VALUES (505, 'Strasbourg Inn', 'East', 3);

CREATE TABLE CulturalEvents (
  EventID NUMBER PRIMARY KEY,
  Region NVARCHAR2(50),
  Name NVARCHAR2(100),
  EventDate DATE,
  EventType NVARCHAR2(50)
);
INSERT INTO CulturalEvents VALUES (401, 'East', 'Fete de la Musique', TO_DATE('2025-08-05','YYYY-MM-DD'), 'Cultural');
INSERT INTO CulturalEvents VALUES (402, 'East', 'Lyon Light Festival', TO_DATE('2025-08-20','YYYY-MM-DD'), 'Art');
INSERT INTO CulturalEvents VALUES (403, 'East', 'Strasbourg Christmas Market', TO_DATE('2025-08-22','YYYY-MM-DD'), 'Seasonal');

COMMIT;
