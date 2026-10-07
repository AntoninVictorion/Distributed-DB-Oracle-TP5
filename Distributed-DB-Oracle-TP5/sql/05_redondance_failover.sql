-- ################################################################################
-- # PARTIE 5 - REDONDANCE ET TOLERANCE AUX PANNES
-- ################################################################################

-- ================================================================================
-- >>> CONNEXION : data
-- ================================================================================
CREATE TABLE Trips_North_Replica (
  TripID NUMBER PRIMARY KEY,
  Region NVARCHAR2(50),
  StartDate DATE,
  EndDate DATE
);
INSERT INTO Trips_North_Replica VALUES (101, 'North', TO_DATE('2025-06-01','YYYY-MM-DD'), TO_DATE('2025-06-10','YYYY-MM-DD'));
INSERT INTO Trips_North_Replica VALUES (104, 'North', TO_DATE('2025-06-15','YYYY-MM-DD'), TO_DATE('2025-06-25','YYYY-MM-DD'));
INSERT INTO Trips_North_Replica VALUES (107, 'North', TO_DATE('2025-07-01','YYYY-MM-DD'), TO_DATE('2025-07-07','YYYY-MM-DD'));
COMMIT;


-- ================================================================================
-- >>> CONNEXION : central
-- ================================================================================
-- 5.2 Procedure de failover
-- CORRECTION : OPEN + FOR ... IN c_trips ouvrait le curseur deux fois (ORA-06511)
--              -> remplace par un FETCH manuel
CREATE OR REPLACE PROCEDURE Query_North_Trips AS
  CURSOR c_trips IS SELECT * FROM Trips@north_link;
  v_trip          c_trips%ROWTYPE;
  v_error_code    NUMBER;
  v_error_message VARCHAR2(200);
BEGIN
  DBMS_OUTPUT.PUT_LINE('Attempting to connect to the primary North site...');
  BEGIN
    OPEN c_trips;
    DBMS_OUTPUT.PUT_LINE('Connection successful. Displaying trips from the primary site:');
    LOOP
      FETCH c_trips INTO v_trip;
      EXIT WHEN c_trips%NOTFOUND;
      DBMS_OUTPUT.PUT_LINE('TripID: ' || v_trip.TripID || ', Region: ' || v_trip.Region);
    END LOOP;
    CLOSE c_trips;
  EXCEPTION
    WHEN OTHERS THEN
      v_error_code    := SQLCODE;
      v_error_message := SQLERRM;
      DBMS_OUTPUT.PUT_LINE('Connection to primary site failed. Error: ' || v_error_message);
      DBMS_OUTPUT.PUT_LINE('Failing over to the North region replica...');
      FOR trip_rec IN (SELECT * FROM Trips_North_Replica@data_link) LOOP
        DBMS_OUTPUT.PUT_LINE('TripID: ' || trip_rec.TripID || ', Region: ' || trip_rec.Region);
      END LOOP;
      DBMS_OUTPUT.PUT_LINE('Failover successful. Data retrieved from replica.');
  END;
END;
/

-- 5.3 Test 1 (succes)
SET SERVEROUTPUT ON;
EXECUTE Query_North_Trips;


-- ================================================================================
-- >>> CONNEXION : admin_xepdb1
-- ================================================================================
-- Test 2 : simulation de la panne du site Nord
-- (CORRECTION : ACCOUNT LOCK plus fiable que REVOKE CONNECT)
ALTER USER north_user ACCOUNT LOCK;


-- ================================================================================
-- >>> CONNEXION : central   (DECONNECTER puis RECONNECTER la session avant !)
-- ================================================================================
-- Le DB link reste ouvert dans la session : sans reconnexion, le verrouillage
-- n'est pas pris en compte (ORA-02080 si on tente de fermer le lien).
SET SERVEROUTPUT ON;
EXECUTE Query_North_Trips;
-- attendu : ORA-28000 (compte verrouille) + ORA-02063, bascule sur la replique,
--           3 voyages, "Failover successful."


-- ================================================================================
-- >>> CONNEXION : admin_xepdb1
-- ================================================================================
-- Restauration du site Nord
ALTER USER north_user ACCOUNT UNLOCK;
