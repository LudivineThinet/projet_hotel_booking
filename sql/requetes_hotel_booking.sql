-- Contrôle
SELECT COUNT(*)                              AS nb_reservations,
       SUM(est_annule)                       AS nb_annulations,
       ROUND(100.0 * AVG(est_annule), 1)     AS taux_annulation_pct,
       ROUND(SUM(total_revenue) / 1e6, 2)    AS ca_potentiel_meur
FROM reservations;

-- Requête 1 - Vue d'ensemble par hôtel
SELECT hotel,
       COUNT(*)                                                             AS nb_reservations,
       SUM(est_annule)                                                      AS nb_annulations,
       ROUND(100.0 * AVG(est_annule), 1)                                    AS taux_annulation_pct,
       ROUND(SUM(CASE WHEN est_annule = 0 THEN total_revenue ELSE 0 END) / 1e6, 2) AS ca_realise_meur,
       ROUND(SUM(CASE WHEN est_annule = 1 THEN total_revenue ELSE 0 END) / 1e6, 2) AS ca_perdu_meur,
       ROUND(100.0 * SUM(CASE WHEN est_annule = 1 THEN total_revenue ELSE 0 END)
             / SUM(total_revenue), 1)                                       AS part_ca_perdu_pct
FROM reservations
GROUP BY hotel
ORDER BY nb_reservations DESC;

-- Requête 2 - Segments de marché
SELECT segment_marche,
       COUNT(*)                                                             AS nb_reservations,
       ROUND(100.0 * AVG(est_annule), 1)                                    AS taux_annulation_pct,
       CASE WHEN AVG(est_annule) > (SELECT AVG(est_annule) FROM reservations)
            THEN 'Au-dessus' ELSE 'En dessous' END                          AS vs_moyenne_groupe,
       ROUND(SUM(CASE WHEN est_annule = 0 THEN total_revenue ELSE 0 END) / 1e6, 2) AS ca_realise_meur,
       ROUND(SUM(CASE WHEN est_annule = 1 THEN total_revenue ELSE 0 END) / 1e6, 2) AS ca_perdu_meur,
       ROUND(100.0 * SUM(CASE WHEN est_annule = 1 THEN total_revenue ELSE 0 END)
             / (SELECT SUM(total_revenue) FROM reservations WHERE est_annule = 1), 1) AS part_du_ca_perdu_pct
FROM reservations
GROUP BY segment_marche
HAVING COUNT(*) >= 100
ORDER BY ca_perdu_meur DESC;

-- Requête 3 - Évolution mensuelle (CTE + LAG)
WITH mensuel AS (
    SELECT hotel,
           annee_arrivee                      AS annee,
           num_mois                           AS mois,
           COUNT(*)                           AS nb_reservations,
           ROUND(100.0 * AVG(est_annule), 1)  AS taux_annulation_pct
    FROM reservations
    GROUP BY hotel, annee_arrivee, num_mois
)
SELECT hotel,
       annee,
       mois,
       nb_reservations,
       taux_annulation_pct,
       LAG(taux_annulation_pct) OVER (PARTITION BY hotel ORDER BY annee, mois)  AS taux_mois_precedent,
       ROUND(taux_annulation_pct
             - LAG(taux_annulation_pct) OVER (PARTITION BY hotel ORDER BY annee, mois), 1) AS ecart_points
FROM mensuel
ORDER BY hotel, annee, mois;

-- Requête 4 - Top 10 des agents (RANK, SUM OVER)
WITH agents AS (
    SELECT CAST(id_agent AS INTEGER)                                        AS agent,
           COUNT(*)                                                         AS nb_reservations,
           ROUND(100.0 * AVG(est_annule), 1)                                AS taux_annulation_pct,
           SUM(CASE WHEN est_annule = 0 THEN total_revenue ELSE 0 END)      AS ca_realise
    FROM reservations
    WHERE id_agent IS NOT NULL
    GROUP BY CAST(id_agent AS INTEGER)
)
SELECT RANK() OVER (ORDER BY ca_realise DESC)                               AS rang,
       agent,
       nb_reservations,
       taux_annulation_pct,
       ROUND(ca_realise / 1e6, 2)                                           AS ca_realise_meur,
       ROUND(100.0 * ca_realise
             / (SELECT SUM(total_revenue) FROM reservations WHERE est_annule = 0), 1) AS part_ca_total_pct,
       ROUND(100.0 * SUM(ca_realise) OVER (ORDER BY ca_realise DESC)
             / (SELECT SUM(total_revenue) FROM reservations WHERE est_annule = 0), 1) AS part_cumulee_pct
FROM agents
ORDER BY rang
LIMIT 10;

-- Requête 5 - Délai de réservation (CTE + CASE)
WITH tranches AS (
    SELECT est_annule,
           total_revenue,
           CASE
               WHEN delai_reservation_jours <= 7   THEN '1. 0-7 jours'
               WHEN delai_reservation_jours <= 30  THEN '2. 8-30 jours'
               WHEN delai_reservation_jours <= 90  THEN '3. 31-90 jours'
               WHEN delai_reservation_jours <= 180 THEN '4. 91-180 jours'
               ELSE '5. Plus de 180 jours'
           END AS tranche_delai
    FROM reservations
)
SELECT tranche_delai,
       COUNT(*)                                                             AS nb_reservations,
       ROUND(100.0 * AVG(est_annule), 1)                                    AS taux_annulation_pct,
       ROUND(SUM(CASE WHEN est_annule = 1 THEN total_revenue ELSE 0 END) / 1e6, 2) AS ca_perdu_meur,
       ROUND(100.0 * SUM(CASE WHEN est_annule = 1 THEN total_revenue ELSE 0 END)
             / (SELECT SUM(total_revenue) FROM reservations WHERE est_annule = 1), 1) AS part_du_ca_perdu_pct
FROM tranches
GROUP BY tranche_delai
ORDER BY tranche_delai;

-- Requête 6 - Profils segment x type de client
SELECT segment_marche,
       type_client,
       COUNT(*)                                                             AS nb_reservations,
       ROUND(100.0 * AVG(est_annule), 1)                                    AS taux_annulation_pct,
       ROUND(SUM(CASE WHEN est_annule = 1 THEN total_revenue ELSE 0 END) / 1e6, 2) AS ca_perdu_meur
FROM reservations
GROUP BY segment_marche, type_client
HAVING COUNT(*) >= 500
ORDER BY taux_annulation_pct DESC
LIMIT 10;

