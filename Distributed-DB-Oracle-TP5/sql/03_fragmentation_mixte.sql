-- ################################################################################
-- # PARTIE 3 - FRAGMENTATION MIXTE (Bookings)
-- ################################################################################

-- ================================================================================
-- >>> CONNEXION : north
-- ================================================================================
CREATE TABLE Booking_Info (
  BookingID NUMBER PRIMARY KEY,
  TouristID NUMBER,
  TripID NUMBER
);
INSERT INTO Booking_Info VALUES (201, 1, 101);
INSERT INTO Booking_Info VALUES (203, 3, 104);
COMMIT;


-- ================================================================================
-- >>> CONNEXION : south
-- ================================================================================
CREATE TABLE Booking_Info (
  BookingID NUMBER PRIMARY KEY,
  TouristID NUMBER,
  TripID NUMBER
);
INSERT INTO Booking_Info VALUES (202, 2, 103);
COMMIT;


-- ================================================================================
-- >>> CONNEXION : east
-- ================================================================================
CREATE TABLE Booking_Info (
  BookingID NUMBER PRIMARY KEY,
  TouristID NUMBER,
  TripID NUMBER
);
INSERT INTO Booking_Info VALUES (204, 4, 107);
COMMIT;


-- ================================================================================
-- >>> CONNEXION : data
-- ================================================================================
CREATE TABLE Booking_Amount (
  BookingID NUMBER PRIMARY KEY,
  Amount NUMBER
);
INSERT INTO Booking_Amount VALUES (201, 800);
INSERT INTO Booking_Amount VALUES (202, 750);
INSERT INTO Booking_Amount VALUES (203, 900);
INSERT INTO Booking_Amount VALUES (204, 650);
COMMIT;
