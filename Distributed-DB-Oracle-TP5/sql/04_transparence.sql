-- ################################################################################
-- # PARTIE 4 - TRANSPARENCE (siege : central_user)
-- ################################################################################

-- ================================================================================
-- >>> CONNEXION : admin_xepdb1
-- ================================================================================
CREATE USER central_user IDENTIFIED BY central_pass;
-- CORRECTION : CREATE VIEW et CREATE DATABASE LINK absents de l'enonce
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE DATABASE LINK TO central_user;


-- ================================================================================
-- >>> CONNEXION : central
-- ================================================================================
-- 4.1 Database links
CREATE DATABASE LINK north_link
  CONNECT TO north_user IDENTIFIED BY north_pass
  USING 'XEPDB1';

CREATE DATABASE LINK south_link
  CONNECT TO south_user IDENTIFIED BY south_pass
  USING 'XEPDB1';

CREATE DATABASE LINK east_link
  CONNECT TO east_user IDENTIFIED BY east_pass
  USING 'XEPDB1';

CREATE DATABASE LINK data_link
  CONNECT TO data_user IDENTIFIED BY data_pass
  USING 'XEPDB1';

-- 4.2 Vues globales (CORRECTION : UNION ALL car fragments disjoints)
CREATE OR REPLACE VIEW All_Trips AS
SELECT TripID, Region, StartDate, EndDate FROM Trips@north_link
UNION ALL
SELECT TripID, Region, StartDate, EndDate FROM Trips@south_link
UNION ALL
SELECT TripID, Region, StartDate, EndDate FROM Trips@east_link;

CREATE OR REPLACE VIEW All_Guides AS
SELECT GuideID, Name, Region, Languages FROM Guides@north_link
UNION ALL
SELECT GuideID, Name, Region, Languages FROM Guides@south_link
UNION ALL
SELECT GuideID, Name, Region, Languages FROM Guides@east_link;

CREATE OR REPLACE VIEW All_Accommodations AS
SELECT HotelID, Name, Region, Rating FROM Accommodations@north_link
UNION ALL
SELECT HotelID, Name, Region, Rating FROM Accommodations@south_link
UNION ALL
SELECT HotelID, Name, Region, Rating FROM Accommodations@east_link;

CREATE OR REPLACE VIEW All_CulturalEvents AS
SELECT EventID, Region, Name, EventDate, EventType FROM CulturalEvents@north_link
UNION ALL
SELECT EventID, Region, Name, EventDate, EventType FROM CulturalEvents@south_link
UNION ALL
SELECT EventID, Region, Name, EventDate, EventType FROM CulturalEvents@east_link;

CREATE OR REPLACE VIEW All_Tourists AS
SELECT tb.TouristID, tb.Name, tb.Nationality, tc.Contact
FROM   Tourist_Basic@data_link tb
JOIN   Tourist_Contact@data_link tc ON tb.TouristID = tc.TouristID;

CREATE OR REPLACE VIEW All_Bookings AS
SELECT bi.BookingID, bi.TouristID, bi.TripID, ba.Amount
FROM  (SELECT BookingID, TouristID, TripID FROM Booking_Info@north_link
       UNION ALL
       SELECT BookingID, TouristID, TripID FROM Booking_Info@south_link
       UNION ALL
       SELECT BookingID, TouristID, TripID FROM Booking_Info@east_link) bi
JOIN   Booking_Amount@data_link ba ON bi.BookingID = ba.BookingID;

-- Verifications
SELECT view_name FROM user_views;
SELECT COUNT(*) FROM All_Trips;      -- attendu : 9
SELECT COUNT(*) FROM All_Bookings;   -- attendu : 4

-- 4.3 Requetes
SELECT * FROM All_Trips;

SELECT T.Name, B.Amount, Trips.Region
FROM   All_Tourists T
JOIN   All_Bookings B ON T.TouristID = B.TouristID
JOIN   All_Trips Trips ON B.TripID = Trips.TripID;

-- 4.4 Procedure d'itineraire (CORRECTION : Date -> EventDate)
CREATE OR REPLACE PROCEDURE Generate_Tourist_Itinerary(p_TouristID NUMBER) AS
  v_Name   NVARCHAR2(100);
  v_TripID NUMBER;
  v_Region NVARCHAR2(50);
  v_Start  DATE;
  v_End    DATE;
BEGIN
  SELECT Name INTO v_Name FROM All_Tourists WHERE TouristID = p_TouristID;

  SELECT Trips.Region, Trips.StartDate, Trips.EndDate, Bookings.TripID
  INTO   v_Region, v_Start, v_End, v_TripID
  FROM   All_Bookings Bookings
  JOIN   All_Trips Trips ON Bookings.TripID = Trips.TripID
  WHERE  Bookings.TouristID = p_TouristID;

  DBMS_OUTPUT.PUT_LINE('--- Itinerary for ' || v_Name || ' ---');
  DBMS_OUTPUT.PUT_LINE('Trip ID: ' || v_TripID);
  DBMS_OUTPUT.PUT_LINE('Region: ' || v_Region);
  DBMS_OUTPUT.PUT_LINE('From: ' || TO_CHAR(v_Start,'DD-MM-YYYY') || ' To ' || TO_CHAR(v_End,'DD-MM-YYYY'));

  DBMS_OUTPUT.PUT_LINE('Guide:');
  FOR guide_rec IN (SELECT Name FROM All_Guides WHERE Region = v_Region) LOOP
    DBMS_OUTPUT.PUT_LINE('- ' || guide_rec.Name);
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('Cultural Events:');
  FOR event_rec IN (SELECT Name FROM All_CulturalEvents
                    WHERE Region = v_Region AND EventDate BETWEEN v_Start AND v_End) LOOP
    DBMS_OUTPUT.PUT_LINE('- ' || event_rec.Name);
  END LOOP;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No itinerary found for TouristID ' || p_TouristID);
END;
/

SET SERVEROUTPUT ON;
EXECUTE Generate_Tourist_Itinerary(1);
-- Tests facultatifs :
-- EXECUTE Generate_Tourist_Itinerary(4);    -- voyage 107, sans evenement
-- EXECUTE Generate_Tourist_Itinerary(99);   -- touriste inexistant
