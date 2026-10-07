# Distributed-DB-Oracle-TP5

Simulation d'une **base de données distribuée Oracle** pour une agence de voyages culturels (régions Nord, Sud, Est et siège à Paris), réalisée avec une seule instance Oracle XE 21c : chaque **schéma** représente un site.

## Ce que le projet démontre

| Partie | Concept | Contenu |
|---|---|---|
| 1 | Fragmentation horizontale | `Trips`, `Guides`, `Accommodations`, `CulturalEvents` répartis par région |
| 2 | Fragmentation verticale | `Tourists` scindée en `Tourist_Basic` et `Tourist_Contact` |
| 3 | Fragmentation mixte | `Bookings` : `Booking_Info` (horizontal) + `Booking_Amount` (vertical) |
| 4 | Transparence | DB links, 6 vues globales, procédure `Generate_Tourist_Itinerary` |
| 5 | Réplication et tolérance aux pannes | `Trips_North_Replica` + procédure de failover `Query_North_Trips` |
| 6 | Cohérence et conflits | `LastUpdated`, mises à jour concurrentes, « last writer wins » |

## Architecture

Un PDB (`XEPDB1`) contenant 5 schémas ; le siège `central_user` n'a aucune donnée locale et accède aux 4 autres sites par 4 DB links.

| Schéma | Rôle |
|---|---|
| `north_user`, `south_user`, `east_user` | Sites régionaux (fragments horizontaux) |
| `data_user` | Données non régionales (contacts, montants) et réplique |
| `central_user` | Siège : liens, vues globales, procédures |

## Structure du dépôt

```
sql/    scripts SQL, un fichier par partie, à exécuter dans l'ordre 01 → 06
docs/   récapitulatif détaillé du TP (concepts, résultats, corrections)
```

Chaque script indique, par un en-tête `>>> CONNEXION : ...`, la connexion SQL Developer à utiliser (`admin_xepdb1`, `north`, `south`, `east`, `data`, `central`).

## Mise en route

1. Lancer Oracle XE 21c, par exemple avec Docker :
   ```bash
   docker run -d --name oracle-xe -p 1521:1521 -p 5500:5500 \
     -e ORACLE_PASSWORD=<mot_de_passe_system> gvenzl/oracle-xe:21-slim
   ```
2. Créer les connexions SQL Developer sur `localhost:1521`, **Service name `XEPDB1`** (travailler dans le PDB, pas dans la racine `XE`, sinon `ORA-65096`).
3. Exécuter les scripts de `sql/` dans l'ordre, avec la connexion indiquée en tête de chaque bloc.

## Points d'attention

- Les mots de passe des schémas (`north_pass`, etc.) sont des valeurs de démonstration. Le mot de passe `system` est à remplacer par le vôtre.
- Corrections apportées aux consignes d'origine : privilèges `CREATE VIEW` et `CREATE DATABASE LINK`, quota de `data_user`, `UNION ALL` pour des fragments disjoints, `EventDate` dans la procédure d'itinéraire, `FETCH` manuel dans le failover (sinon `ORA-06511`), `COMMIT` après les `INSERT`.
- Les vues globales listent leurs colonnes explicitement : un `SELECT *` est figé à la création de la vue et casse (`ORA-01789`) si un fragment change de schéma.
- Test de panne : `ALTER USER north_user ACCOUNT LOCK`, puis reconnecter la session `central` (un DB link reste ouvert dans la session).
- « Last writer wins » détecte le gagnant mais supprime silencieusement l'autre modification ; il dépend aussi de la synchronisation des horloges entre sites.

Le détail complet est dans [`docs/TP5_recapitulatif.md`](docs/TP5_recapitulatif.md).
