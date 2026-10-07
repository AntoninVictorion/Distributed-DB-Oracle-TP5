-- ################################################################################
-- # PARTIE 2 - FRAGMENTATION VERTICALE (Tourists)
-- ################################################################################

-- ================================================================================
-- >>> CONNEXION : admin_xepdb1
-- ================================================================================
CREATE USER data_user IDENTIFIED BY data_pass;
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE DATABASE LINK TO data_user;
-- CORRECTION : quota oublie dans l'enonce
ALTER USER data_user QUOTA UNLIMITED ON users;


-- ================================================================================
-- >>> CONNEXION : data
-- ================================================================================
CREATE TABLE Tourist_Basic (
  TouristID NUMBER PRIMARY KEY,
  Name NVARCHAR2(100),
  Nationality NVARCHAR2(50)
);
CREATE TABLE Tourist_Contact (
  TouristID NUMBER PRIMARY KEY,
  Contact NVARCHAR2(50)
);

INSERT INTO Tourist_Basic VALUES (1, 'Paul Martin', 'French');
INSERT INTO Tourist_Contact VALUES (1, '0612345678');
INSERT INTO Tourist_Basic VALUES (2, 'Sofia Rossi', 'Italian');
INSERT INTO Tourist_Contact VALUES (2, '003934567890');
INSERT INTO Tourist_Basic VALUES (3, 'David Wilson', 'British');
INSERT INTO Tourist_Contact VALUES (3, '07700900123');
INSERT INTO Tourist_Basic VALUES (4, 'Chen Lee', 'Chinese');
INSERT INTO Tourist_Contact VALUES (4, '+8613800138000');

COMMIT;
