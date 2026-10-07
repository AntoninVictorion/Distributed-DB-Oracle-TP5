# TP5 – Base de données distribuée Oracle (Cultural Trip Organization) – Document complet

> Récapitulatif du TP 5 (parties 1 à 6, terminé et validé). Dernière mise à jour : 07/10/2026.

---

## 1. Objectif du TP

Simuler une base distribuée pour une agence de voyages (régions Nord, Sud, Est + siège à Paris) avec **une seule instance Oracle**, en utilisant des **schémas** comme sites fictifs.

| Partie | Concept du cours | Contenu | État |
|---|---|---|---|
| 1 | Fragmentation horizontale (σ) | `Trips`, `Guides`, `Accommodations`, `CulturalEvents` par région | ✅ |
| 2 | Fragmentation verticale (Π) | `Tourists` → `Tourist_Basic` + `Tourist_Contact` dans `data_user` | ✅ |
| 3 | Fragmentation mixte | `Bookings` → `Booking_Info` (horizontal) + `Booking_Amount` (vertical) | ✅ |
| 4 | Transparence | DB links, 6 vues globales, requêtes, procédure `Generate_Tourist_Itinerary` | ✅ |
| 5 | Réplication / tolérance aux pannes | `Trips_North_Replica` + procédure `Query_North_Trips` (failover) | ✅ |
| 6 | Cohérence / conflits | `LastUpdated`, mises à jour concurrentes, « last writer wins » | ✅ |

---

## 2. Environnement

| Élément | Valeur |
|---|---|
| Outils | SQL Developer (64 bits Windows), Docker Desktop, terminal WSL |
| Conteneur | `oracle-xe` (image `gvenzl/oracle-xe:21-slim`, Oracle XE 21c) |
| Ports | `1521->1521` (listener), `5500->5500` (EM Express) |
| PDB | **`XEPDB1`** |
| Mot de passe `system` | `<mot_de_passe_system>` |
| Connexion admin | `admin_xepdb1` (system, localhost, 1521, **Service name** `XEPDB1`) |

Démarrage : `docker start oracle-xe` ; la base est prête quand les logs affichent `Pluggable database XEPDB1 opened read write`.

**Connexions SQL Developer** (même hôte/port, service `XEPDB1`) : `admin_xepdb1`, `north`, `south`, `east`, `data`, `central`.

### Schémas (sites simulés)

| Schéma | Mot de passe | Rôle |
|---|---|---|
| `north_user` | `north_pass` | Site régional Nord |
| `south_user` | `south_pass` | Site régional Sud |
| `east_user` | `east_pass` | Site régional Est |
| `data_user` | `data_pass` | Site central des données non régionales (contacts, montants, réplique) |
| `central_user` | `central_pass` | Siège : **aucune donnée locale**, uniquement liens, vues, procédures |

Architecture : un PDB (`XEPDB1`) contenant 5 schémas ; `central_user` accède aux 4 autres via 4 DB links.

---

## 3. Données de référence (table centralisée avant fragmentation)

- **Trips** : 101 North (2025-06-01→06-10), 102 South (07-05→07-15), 103 East (08-01→08-10), 104 North (06-15→06-25), 105 South (07-20→07-30), 106 East (08-15→08-25), + 107 North (07-01→07-07), 108 South (08-05→08-12), 109 East (09-01→09-07) insérés dans le TP.
- **Tourists** : 1 Paul Martin (French), 2 Sofia Rossi (Italian), 3 David Wilson (British), 4 Chen Lee (Chinese).
- **Bookings** : 201 (T1, voyage 101, 800), 202 (T2, voyage 103, 750), 203 (T3, voyage 104, 900), 204 (T4, voyage 107, 650).
- **Guides** : 301 Jean Leclerc (S), 302 Sophie Blanc (E), 303 Antoine Giraud (E), 304 Pierre Dubois (N), 305 Marie Lefevre (N), 306 Lucas Fournier (N), 307 Camille Dubois (S).
- **Accommodations** : 501 Hotel du Nord (N, 4), 502 Normandy Lodge (N, 3), 503 Le Vieux Port (S, 5), 504 Lyon City Hotel (E, 4), 505 Strasbourg Inn (E, 3).
- **CulturalEvents** : 401–403 East, 404–405 North, 406 South.

Répartition obtenue :

| Table | Nord | Sud | Est |
|---|---|---|---|
| `Trips` | 101, 104, 107 | 102, 105, 108 | 103, 106, 109 |
| `Guides` | 304, 305, 306 | 301, 307 | 302, 303 |
| `Accommodations` | 501, 502 | 503 | 504, 505 |
| `CulturalEvents` | 404, 405 | 406 | 401, 402, 403 |
| `Booking_Info` | 201, 203 | 202 | 204 |

---

## 4. Réalisation, partie par partie

### Partie 1 – Fragmentation horizontale

Connexion `admin_xepdb1` (création des utilisateurs ; même schéma pour south et east) :

```sql
CREATE USER north_user IDENTIFIED BY north_pass;
GRANT CONNECT, RESOURCE TO north_user;
ALTER USER north_user QUOTA UNLIMITED ON users;
-- idem south_user / south_pass et east_user / east_pass
```

Dans chaque schéma régional (exemple Nord, connexion `north`) :

```sql
CREATE TABLE Trips (
  TripID NUMBER PRIMARY KEY, Region NVARCHAR2(50), StartDate DATE, EndDate DATE);
INSERT INTO Trips VALUES (101,'North',TO_DATE('2025-06-01','YYYY-MM-DD'),TO_DATE('2025-06-10','YYYY-MM-DD'));
INSERT INTO Trips VALUES (104,'North',TO_DATE('2025-06-15','YYYY-MM-DD'),TO_DATE('2025-06-25','YYYY-MM-DD'));
INSERT INTO Trips VALUES (107,'North',TO_DATE('2025-07-01','YYYY-MM-DD'),TO_DATE('2025-07-07','YYYY-MM-DD'));

CREATE TABLE Guides (
  GuideID NUMBER PRIMARY KEY, Name NVARCHAR2(100), Region NVARCHAR2(50), Languages NVARCHAR2(100));
INSERT INTO Guides VALUES (304,'Pierre Dubois','North','French, Spanish');
INSERT INTO Guides VALUES (305,'Marie Lefevre','North','French, English, German');
INSERT INTO Guides VALUES (306,'Lucas Fournier','North','French, Arabic');

CREATE TABLE Accommodations (
  HotelID NUMBER PRIMARY KEY, Name NVARCHAR2(100), Region NVARCHAR2(50), Rating NUMBER);
INSERT INTO Accommodations VALUES (501,'Hotel du Nord','North',4);
INSERT INTO Accommodations VALUES (502,'Normandy Lodge','North',3);

CREATE TABLE CulturalEvents (
  EventID NUMBER PRIMARY KEY, Region NVARCHAR2(50), Name NVARCHAR2(100),
  EventDate DATE, EventType NVARCHAR2(50));
INSERT INTO CulturalEvents VALUES (404,'North','Paris Jazz Festival',TO_DATE('2025-06-05','YYYY-MM-DD'),'Cultural');
INSERT INTO CulturalEvents VALUES (405,'North','D-Day Commemoration',TO_DATE('2025-06-06','YYYY-MM-DD'),'Historical');
COMMIT;
```

Sud et Est : mêmes tables avec les lignes de la région (cf. tableau §3). **Chaque fragment est une sélection σ région = X** de la table globale.

### Partie 2 – Fragmentation verticale

Admin :
```sql
CREATE USER data_user IDENTIFIED BY data_pass;
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE DATABASE LINK TO data_user;
ALTER USER data_user QUOTA UNLIMITED ON users;   -- oublié dans l'énoncé
```

Connexion `data` :
```sql
CREATE TABLE Tourist_Basic (TouristID NUMBER PRIMARY KEY, Name NVARCHAR2(100), Nationality NVARCHAR2(50));
CREATE TABLE Tourist_Contact (TouristID NUMBER PRIMARY KEY, Contact NVARCHAR2(50));
INSERT INTO Tourist_Basic VALUES (1,'Paul Martin','French');   INSERT INTO Tourist_Contact VALUES (1,'0612345678');
INSERT INTO Tourist_Basic VALUES (2,'Sofia Rossi','Italian');  INSERT INTO Tourist_Contact VALUES (2,'003934567890');
INSERT INTO Tourist_Basic VALUES (3,'David Wilson','British'); INSERT INTO Tourist_Contact VALUES (3,'07700900123');
INSERT INTO Tourist_Basic VALUES (4,'Chen Lee','Chinese');     INSERT INTO Tourist_Contact VALUES (4,'+8613800138000');
COMMIT;
```

`TouristID` = clé commune → **reconstruction sans perte (lossless join)**. Motivation : séparer les données sensibles (contact) pour la sécurité.

### Partie 3 – Fragmentation mixte (`Bookings`)

- **Horizontal** : `Booking_Info(BookingID, TouristID, TripID)` dans chaque schéma régional (Nord : 201, 203 ; Sud : 202 ; Est : 204).
- **Vertical** : `Booking_Amount(BookingID, Amount)` dans `data_user` (201→800, 202→750, 203→900, 204→650).

```sql
-- Connexions north / south / east
CREATE TABLE Booking_Info (BookingID NUMBER PRIMARY KEY, TouristID NUMBER, TripID NUMBER);
INSERT INTO Booking_Info VALUES (201,1,101);   -- Nord (et 203,3,104) ; Sud : (202,2,103) ; Est : (204,4,107)
COMMIT;

-- Connexion data
CREATE TABLE Booking_Amount (BookingID NUMBER PRIMARY KEY, Amount NUMBER);
INSERT INTO Booking_Amount VALUES (201,800);
INSERT INTO Booking_Amount VALUES (202,750);
INSERT INTO Booking_Amount VALUES (203,900);
INSERT INTO Booking_Amount VALUES (204,650);
COMMIT;
```

### Partie 4 – Transparence

**4.1 – Utilisateur central et DB links** (admin puis connexion `central`) :
```sql
CREATE USER central_user IDENTIFIED BY central_pass;
GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE DATABASE LINK TO central_user;  -- les 2 derniers privilèges manquent dans l'énoncé

-- Connexion central
CREATE DATABASE LINK north_link CONNECT TO north_user IDENTIFIED BY north_pass USING 'XEPDB1';
CREATE DATABASE LINK south_link CONNECT TO south_user IDENTIFIED BY south_pass USING 'XEPDB1';
CREATE DATABASE LINK east_link  CONNECT TO east_user  IDENTIFIED BY east_pass  USING 'XEPDB1';
CREATE DATABASE LINK data_link  CONNECT TO data_user  IDENTIFIED BY data_pass  USING 'XEPDB1';
```
Un DB link est un « pointeur » stocké dans la base (utilisateur distant + chaîne de connexion) ; les 4 liens pointent vers le même PDB mais se connectent chacun en tant que **schéma-site** différent.

**4.2 – Vues globales** (connexion `central`), version corrigée `UNION ALL` :
```sql
CREATE OR REPLACE VIEW All_Trips AS
SELECT * FROM Trips@north_link UNION ALL
SELECT * FROM Trips@south_link UNION ALL
SELECT * FROM Trips@east_link;
-- idem All_Guides, All_Accommodations, All_CulturalEvents

CREATE OR REPLACE VIEW All_Tourists AS
SELECT tb.TouristID, tb.Name, tb.Nationality, tc.Contact
FROM   Tourist_Basic@data_link tb
JOIN   Tourist_Contact@data_link tc ON tb.TouristID = tc.TouristID;

CREATE OR REPLACE VIEW All_Bookings AS
SELECT bi.BookingID, bi.TouristID, bi.TripID, ba.Amount
FROM  (SELECT * FROM Booking_Info@north_link UNION ALL
       SELECT * FROM Booking_Info@south_link UNION ALL
       SELECT * FROM Booking_Info@east_link) bi
JOIN   Booking_Amount@data_link ba ON bi.BookingID = ba.BookingID;
```
Vérifications : 6 vues présentes ; `All_Trips` = **9** voyages ; `All_Bookings` = **4** réservations.

**4.3 – Requêtes** :
```sql
SELECT * FROM All_Trips;   -- 9 lignes

SELECT T.Name, B.Amount, Trips.Region
FROM   All_Tourists T
JOIN   All_Bookings B ON T.TouristID = B.TouristID
JOIN   All_Trips Trips ON B.TripID = Trips.TripID;
```
Résultat de la jointure : Paul Martin 800 North ; Sofia Rossi 750 East ; David Wilson 900 North ; Chen Lee 650 North (4 lignes).
Plan d'exécution de `SELECT * FROM All_Trips` : `VIEW ALL_TRIPS` → `UNION-ALL` (pas de `SORT UNIQUE`) → 3 × `REMOTE` (un par site). Le « Remote SQL Information » montre la décomposition en sous-requêtes par site (cycle de vie : décomposition, localisation, optimisation, exécution locale, assemblage).

**4.4 – Procédure `Generate_Tourist_Itinerary`** (connexion `central`). Correction vs énoncé : `Date` → `EventDate`.
```sql
CREATE OR REPLACE PROCEDURE Generate_Tourist_Itinerary(p_TouristID NUMBER) AS
  v_Name NVARCHAR2(100); v_TripID NUMBER; v_Region NVARCHAR2(50); v_Start DATE; v_End DATE;
BEGIN
  SELECT Name INTO v_Name FROM All_Tourists WHERE TouristID = p_TouristID;
  SELECT Trips.Region, Trips.StartDate, Trips.EndDate, Bookings.TripID
  INTO   v_Region, v_Start, v_End, v_TripID
  FROM   All_Bookings Bookings JOIN All_Trips Trips ON Bookings.TripID = Trips.TripID
  WHERE  Bookings.TouristID = p_TouristID;

  DBMS_OUTPUT.PUT_LINE('--- Itinerary for ' || v_Name || ' ---');
  DBMS_OUTPUT.PUT_LINE('Trip ID: ' || v_TripID);
  DBMS_OUTPUT.PUT_LINE('Region: ' || v_Region);
  DBMS_OUTPUT.PUT_LINE('From: ' || TO_CHAR(v_Start,'DD-MM-YYYY') || ' To ' || TO_CHAR(v_End,'DD-MM-YYYY'));
  DBMS_OUTPUT.PUT_LINE('Guide:');
  FOR g IN (SELECT Name FROM All_Guides WHERE Region = v_Region) LOOP
    DBMS_OUTPUT.PUT_LINE('- ' || g.Name);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Cultural Events:');
  FOR e IN (SELECT Name FROM All_CulturalEvents
            WHERE Region = v_Region AND EventDate BETWEEN v_Start AND v_End) LOOP
    DBMS_OUTPUT.PUT_LINE('- ' || e.Name);
  END LOOP;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('No itinerary found for TouristID ' || p_TouristID);
END;
/
SET SERVEROUTPUT ON;
EXECUTE Generate_Tourist_Itinerary(1);
```
Test validé (touriste 1 : Paul Martin, voyage 101, 3 guides Nord, 2 événements : Paris Jazz Festival, D-Day Commemoration). Tests facultatifs non faits : `(4)` (voyage 107, sans événement) et `(99)` (touriste inexistant → `NO_DATA_FOUND`).

### Partie 5 – Redondance et tolérance aux pannes

**5.1 – Réplique** (connexion `data`) :
```sql
CREATE TABLE Trips_North_Replica (
  TripID NUMBER PRIMARY KEY, Region NVARCHAR2(50), StartDate DATE, EndDate DATE);
INSERT INTO Trips_North_Replica VALUES (101,'North',TO_DATE('2025-06-01','YYYY-MM-DD'),TO_DATE('2025-06-10','YYYY-MM-DD'));
INSERT INTO Trips_North_Replica VALUES (104,'North',TO_DATE('2025-06-15','YYYY-MM-DD'),TO_DATE('2025-06-25','YYYY-MM-DD'));
INSERT INTO Trips_North_Replica VALUES (107,'North',TO_DATE('2025-07-01','YYYY-MM-DD'),TO_DATE('2025-07-07','YYYY-MM-DD'));
COMMIT;
```

**5.2 – Procédure de failover** (connexion `central`). **Bug de l'énoncé** : `OPEN c_trips;` suivi de `FOR trip_rec IN c_trips LOOP` ouvre le curseur deux fois → `ORA-06511: curseur déjà ouvert`. Le `WHEN OTHERS` déclenchait alors un failover **à tort** alors que le Nord fonctionnait (les données de la réplique étant identiques, l'erreur passait inaperçue). Correction : `FETCH` manuel.
```sql
CREATE OR REPLACE PROCEDURE Query_North_Trips AS
  CURSOR c_trips IS SELECT * FROM Trips@north_link;
  v_trip c_trips%ROWTYPE;
  v_error_code NUMBER;
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
      v_error_code := SQLCODE;
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
```

**5.3 – Tests (validés)** :
- **Test 1 (succès)** : `EXECUTE Query_North_Trips;` → 3 voyages depuis le primaire, sans message d'échec.
- **Test 2 (panne simulée)** : `admin_xepdb1` : `ALTER USER north_user ACCOUNT LOCK;`, puis **déconnexion/reconnexion de la session `central`**, puis `EXECUTE Query_North_Trips;` → `ORA-28000: The account is locked` + `ORA-02063: précédant line de NORTH_LINK`, bascule sur la réplique, 3 voyages, « Failover successful ».
- **Restauration** : `ALTER USER north_user ACCOUNT UNLOCK;` → la procédure est de nouveau servie par le primaire.

**Piège** : un DB link reste **ouvert dans la session** après usage ; verrouiller le compte distant n'affecte que les *nouvelles* connexions. `ALTER SESSION CLOSE DATABASE LINK north_link;` a échoué (`ORA-02080`, lien en cours d'utilisation : transaction active ou curseur ouvert gardé par SQL Developer). Solution : déconnecter puis reconnecter `central`. `REVOKE CONNECT` (suggéré par l'énoncé) est approximatif ; `ACCOUNT LOCK/UNLOCK` est plus fiable.

### Partie 6 – Conflits de mise à jour (« last writer wins »)

**6.1 – Colonne `LastUpdated`**
```sql
-- Connexion north
ALTER TABLE Trips ADD LastUpdated TIMESTAMP;
UPDATE Trips SET LastUpdated = SYSTIMESTAMP;
COMMIT;

-- Connexion data
ALTER TABLE Trips_North_Replica ADD LastUpdated TIMESTAMP;
UPDATE Trips_North_Replica SET LastUpdated = SYSTIMESTAMP;
COMMIT;
```

**Vérification de `All_Trips` (connexion `central`)** : `SELECT * FROM All_Trips;` → **9 lignes, 4 colonnes** (`TRIPID, REGION, STARTDATE, ENDDATE`), **aucune erreur `ORA-01789`**.
Explication : Oracle remplace le `*` par la liste explicite de colonnes **au moment de la création de la vue** ; la vue a donc figé 4 colonnes et ignore `LastUpdated`. Conséquences : un fragment peut évoluer sans casser la vue (transparence conservée), mais la vue ne reflète plus le schéma réel du fragment (information masquée). Si on **recréait** la vue avec `SELECT *`, on aurait 5 colonnes au Nord contre 4 ailleurs → `ORA-01789`. D'où l'intérêt d'interroger directement `Trips@north_link` et `Trips_North_Replica@data_link` en 6.3.

**6.2 – Mises à jour concurrentes du voyage 101** (deux sessions, deux `COMMIT` indépendants, pas de verrou commun donc pas d'erreur : conflit **silencieux**, caractéristique de la réplication asynchrone)
```sql
-- Session 1 (connexion north, primaire)
UPDATE Trips
SET EndDate = TO_DATE('2025-06-11','YYYY-MM-DD'), LastUpdated = SYSTIMESTAMP
WHERE TripID = 101;
COMMIT;

-- Session 2 (connexion data, réplique), exécutée après
UPDATE Trips_North_Replica
SET EndDate = TO_DATE('2025-06-12','YYYY-MM-DD'), LastUpdated = SYSTIMESTAMP
WHERE TripID = 101;
COMMIT;
```

**6.3 – Identification de la version gagnante** (connexion `central`)
```sql
SELECT 'Primary Site' AS Source, TripID, EndDate, LastUpdated
FROM   Trips@north_link WHERE TripID = 101
UNION ALL
SELECT 'Replica Site' AS Source, TripID, EndDate, LastUpdated
FROM   Trips_North_Replica@data_link WHERE TripID = 101
ORDER BY LastUpdated DESC;
```

Résultat obtenu :

| Source | TripID | EndDate | LastUpdated |
|---|---|---|---|
| Replica Site | 101 | 12/06/25 | 07/10/26 16:27:25,467166 |
| Primary Site | 101 | 11/06/25 | 07/10/26 16:27:03,577513 |

→ La **réplique gagne** (écrite en dernier) : `EndDate` correct = **2025-06-12**.

**Points d'analyse à retenir pour le rapport** :
- Failover (partie 5) = règle de **disponibilité** (on lit le primaire, la réplique ne sert qu'en cas de panne). Last writer wins (partie 6) = règle de **cohérence** (les deux copies répondent mais divergent ; on garde la plus récente, quel que soit son statut primaire/réplique).
- Le moteur Oracle ne détecte ni ne résout le conflit : c'est **la requête** qui implémente la politique. Dans un vrai système, un processus de réconciliation l'appliquerait automatiquement.
- Limite de LWW : la modification perdante est **supprimée silencieusement**. Alternatives : horloges vectorielles, MVCC (cf. cours, partie NoSQL), primary copy.
- **Horloges** : `SYSTIMESTAMP` renvoie l'heure du serveur (conteneur Docker en UTC : 16:27 affiché pour 18:27 à Paris). Sans conséquence ici (même horloge pour les deux tables), mais des horloges différentes selon les sites sont le point faible de LWW.
- **Piège SQL Developer** : un clic sur l'en-tête d'une colonne de la grille applique un tri **côté client** qui écrase l'`ORDER BY` de la requête (le gagnant s'est d'abord affiché en 2ᵉ ligne). Toujours vérifier que l'ordre affiché vient de la requête.
- **Bonus non exécuté (hors énoncé)** : un `MERGE INTO Trips@north_link ... WHEN MATCHED THEN UPDATE ... WHERE r.LastUpdated > p.LastUpdated` permettrait d'**appliquer** la résolution (le perdant adopte la valeur du gagnant) ; la requête 6.3 ne fait que la détecter. Il ne traite que le sens réplique → primaire.

---

## 5. Concepts du cours reliés au TP

- **CDB / PDB** : se connecter au service `XE` (racine) impose des utilisateurs communs `C##...` (`ORA-65096`). On travaille dans le **PDB `XEPDB1`**.
- **Utilisateur = schéma = site simulé** : deux utilisateurs peuvent avoir chacun une table `Trips` sans conflit.
- **Fragmentation horizontale** : σ ; reconstruction par union ; fragments disjoints → `UNION ALL` (évite un `SORT UNIQUE` inutile).
- **Fragmentation verticale** : Π ; clé commune pour la jointure sans perte.
- **Fragmentation mixte** : combinaison des deux (`Bookings`).
- **Transparence** (fragmentation, localisation, réplication) : l'utilisateur interroge des vues / une procédure sans connaître les sites ni quelle copie répond.
- **Cycle de vie d'une requête distribuée** : décomposition, localisation, optimisation, exécution locale, assemblage (visible dans le plan : `VIEW`, `UNION-ALL`, `REMOTE`).
- **Coût réseau** : les jointures multi-sites rapatrient les données sur `central` (semi-join ; `DRIVING_SITE` possible).
- **Isolation (ACID)** : les modifications non commitées sont invisibles aux autres sessions, y compris via DB link.
- **Réplication** : avantages = disponibilité, parallélisme, moins de transfert ; inconvénients = coût des mises à jour, **contrôle de concurrence plus complexe**. Réplication **asynchrone** (copies périodiquement synchronisées, peuvent diverger) vs **synchrone**.
- **Pannes distribuées** : panne de site et partition réseau sont **indistinguables** ; d'où le `WHEN OTHERS` du failover.

---

## 6. Corrections et limites par rapport à l'énoncé

| Point | Détail |
|---|---|
| Privilèges de `central_user` | L'énoncé donne seulement `CONNECT, RESOURCE` ; ajout de `CREATE VIEW` et `CREATE DATABASE LINK`, sinon `ORA-01031`. |
| Quota de `data_user` | Oublié dans l'énoncé ; ajout de `QUOTA UNLIMITED ON users`. |
| `UNION` vs `UNION ALL` | Fragments disjoints : `UNION ALL` évite un tri de dédoublonnage inutile. |
| `SELECT *` dans les vues | Figé à la création de la vue ; fragile si on recrée la vue après changement de schéma d'un fragment (`ORA-01789`). Préférer une liste explicite de colonnes. |
| `COMMIT` manquant | `All_Bookings` renvoyait 0 ligne car les `INSERT` n'étaient pas commités. **Toujours terminer les scripts de peuplement par `COMMIT;`.** |
| Bug procédure 4.4 | `Date BETWEEN ...` doit être `EventDate BETWEEN ...`. |
| Bug procédure 5.2 | `OPEN` + `FOR ... IN c_trips` → `ORA-06511` ; corrigé par `FETCH` manuel. |
| Intégrité référentielle inter-sites | Réservation 204 (Est) → voyage 107 (Nord) ; réservation 202 (Sud) → voyage 103 (Est). Pas de clé étrangère possible entre sites ; le `JOIN` interne de `All_Bookings` fait disparaître silencieusement une ligne présente d'un seul côté. |
| Limite de la simulation | Oracle ne connaît pas la règle de fragmentation : il interroge toujours les 3 sites, sans élimination de fragments (pas de partition pruning). |
| Test de panne (5.3) | `REVOKE CONNECT` approximatif ; utilisation de `ACCOUNT LOCK` / `UNLOCK` (+ reconnexion de la session `central`). |
| Résolution de conflit (6.3) | Détection seulement ; la réconciliation nécessite un `MERGE` (bonus non exigé). |

---
