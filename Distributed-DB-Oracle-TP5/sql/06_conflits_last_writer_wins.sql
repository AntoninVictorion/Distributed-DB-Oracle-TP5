-- ################################################################################
-- # PARTIE 6 - CONFLITS DE MISE A JOUR (last writer wins)
-- ################################################################################

-- ================================================================================
-- >>> CONNEXION : north
-- ================================================================================
-- 6.1 Colonne d'horodatage sur le primaire
ALTER TABLE Trips ADD LastUpdated TIMESTAMP;
UPDATE Trips SET LastUpdated = SYSTIMESTAMP;
COMMIT;


-- ================================================================================
-- >>> CONNEXION : data
-- ================================================================================
-- 6.1 Colonne d'horodatage sur la replique
ALTER TABLE Trips_North_Replica ADD LastUpdated TIMESTAMP;
UPDATE Trips_North_Replica SET LastUpdated = SYSTIMESTAMP;
COMMIT;


-- ================================================================================
-- >>> CONNEXION : central
-- ================================================================================
-- Verification : la vue All_Trips a fige ses 4 colonnes -> 9 lignes, pas d'ORA-01789
SELECT * FROM All_Trips;


-- ================================================================================
-- >>> CONNEXION : north      (6.2 - Session 1, site primaire)
-- ================================================================================
UPDATE Trips
SET    EndDate     = TO_DATE('2025-06-11','YYYY-MM-DD'),
       LastUpdated = SYSTIMESTAMP
WHERE  TripID = 101;
COMMIT;


-- ================================================================================
-- >>> CONNEXION : data       (6.2 - Session 2, site replique, executee APRES)
-- ================================================================================
UPDATE Trips_North_Replica
SET    EndDate     = TO_DATE('2025-06-12','YYYY-MM-DD'),
       LastUpdated = SYSTIMESTAMP
WHERE  TripID = 101;
COMMIT;


-- ================================================================================
-- >>> CONNEXION : central    (6.3 - identification de la version gagnante)
-- ================================================================================
SELECT 'Primary Site' AS Source, TripID, EndDate, LastUpdated
FROM   Trips@north_link
WHERE  TripID = 101
UNION ALL
SELECT 'Replica Site' AS Source, TripID, EndDate, LastUpdated
FROM   Trips_North_Replica@data_link
WHERE  TripID = 101
ORDER BY LastUpdated DESC;
-- Resultat obtenu : Replica Site (EndDate 12/06/25) en premiere ligne -> elle gagne.
-- Attention : ne pas cliquer sur un en-tete de colonne dans la grille SQL Developer
-- (tri cote client qui ecrase l'ORDER BY).


-- ################################################################################
-- # BONUS (HORS ENONCE, NON EXECUTE) - appliquer la resolution
-- ################################################################################

-- ================================================================================
-- >>> CONNEXION : central
-- ================================================================================
-- MERGE INTO Trips@north_link p
-- USING (SELECT TripID, EndDate, LastUpdated
--        FROM   Trips_North_Replica@data_link) r
-- ON    (p.TripID = r.TripID)
-- WHEN MATCHED THEN
--   UPDATE SET p.EndDate     = r.EndDate,
--              p.LastUpdated = r.LastUpdated
--   WHERE r.LastUpdated > p.LastUpdated;
-- COMMIT;
