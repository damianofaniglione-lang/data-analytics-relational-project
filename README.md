# data-analytics-relational-project
Progetto end-to-end di Data Architecture (SQL) e Business Intelligence (Power BI) applicato alle logiche di cross-selling territoriale.

---

## Data Analytics Project: Cross-Selling & Territoriale Risk Intelligence

L'obiettivo è ottimizzare le strategie di cross-selling e marketing della piattaforma integrando ed elaborando dati provenienti da due comparti aziendali disallineati: **Automotive/Insurtech** (furti di veicoli) e **Utilities/Behavioral** (abbandono, spesa e demografia dei clienti telecom).

---

## Struttura della Repository
*   File di report principale : [Geo-Marketing & Territoriale Risk Intelligence](Geo-Marketing%20&%20Territoriale%20Risk%20Intelligence.pbix)
*   Script di strutturazione del Data Warehouse : [market insights ETL](market-insights-ETL.sql)
*   I 5 Dataset sorgente grezzi in formato `.csv` : (Sorgente: Maven Analytics)
*   [dim_locations](dim_locations.csv);
*   [dim_make_details](dim_make_details.csv);
*   [dim_zipcode_population](dim_zipcode_population.csv);
*   [fct_stolen_vehicles](fct_stolen_vehicles.csv);
*   [fct_telecom_churn](fct_telecom_churn.csv).

---

## Architettura del Data Warehouse Relazionale
I dati grezzi di partenza presentavano una struttura normalizzata. In **MySQL 8.0**, ho progettato uno schema relazionale integrato composto da 3 tabelle di dimensione e 2 tabelle di fatti (*Fact Tables*), implementando vincoli di integrità referenziale (`FOREIGN KEY`):

*   `dim_locations`: Anagrafica territoriale delle regioni, popolazione e densità.
*   `dim_make_details`: Dettagli dei costruttori e tipologia di veicoli.
*   `dim_zipcode_population`: Dati demografici basati sui CAP.
*   `fct_stolen_vehicles`: Registro degli eventi di furto e metriche temporali.
*   `fct_telecom_churn`: Log comportamentali, costi mensili e status di retention dei clienti.

---

## Data Pipeline & Data Cleaning (MySQL 8.0)

Durante la fase di *Data Ingestion* via riga di comando (`MySQL Command Line Client`), ho affrontato e risolto diverse anomalie strutturali tipiche dei database di produzione:
1.  **BOM Character Elimination:** Rimozione dei caratteri invisibili all'inizio dei file CSV (`0xEFBBBF`) forzando la codifica nativa `CHARACTER SET utf8mb4`.
2.  **Data Type Alignment:** Trasformazione di stringhe sporche contenenti formattazioni non standard (es. isolamento dei campi vuoti nei costi totali per i clienti a consumo e pulizia delle virgole nel campo numerico della popolazione con funzioni `REPLACE`).
3.  **Data Harmonization Challenge:** I dataset presentavano un disallineamento geografico nativo (città USA vs regioni Nuova Zelanda). Per simulare un ambiente di produzione coerente senza alterare l'integrità dei record, ho implementato una tecnica di fusione statistica posizionale basata su Window Functions (`ROW_NUMBER() OVER`) ordinando i record per salienza analitica (volumi di furto e spesa massimi).

### La Query Analitica di Business (Core View)
```sql
CREATE OR REPLACE VIEW `market-insights` AS 
WITH stolen_stats AS ( 
    SELECT l.Region, COUNT(s.Vehicle_ID) AS total_thefts, 
           ROW_NUMBER() OVER (ORDER BY COUNT(s.Vehicle_ID) DESC) AS row_num 
    FROM fct_stolen_vehicles s 
    JOIN dim_locations l ON s.Location_ID = l.Location_ID 
    GROUP BY l.Region 
), 
churn_stats AS ( 
    SELECT City, COUNT(Customer_ID) AS total_customers, 
           SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) AS churned_customers, 
           AVG(Monthly_Charge) AS avg_monthly_bill, 
           ROW_NUMBER() OVER (ORDER BY AVG(Monthly_Charge) DESC) AS row_num 
    FROM fct_telecom_churn 
    GROUP BY City 
) 
SELECT 
    c.City AS Area_Geografica,
    c.total_customers AS Clienti_Totali,
    ROUND((c.churned_customers / c.total_customers) * 100, 2) AS Churn_Rate_Percentuale,
    ROUND(c.avg_monthly_bill, 2) AS Spesa_Media_Mensile,
    COALESCE(s.total_thefts, 0) AS Furti_Auto_Registrati, 
    CASE 
        WHEN COALESCE(s.total_thefts, 0) >= 1 AND ROUND((c.churned_customers / c.total_customers) * 100, 2) > 15 THEN 'Target Prioritario: Alta Sinistrosità e Alto Abbandono' 
        WHEN COALESCE(s.total_thefts, 0) >= 1 THEN 'Opportunità Insurtech: Spingere Polizze Furto/Incendio' 
        WHEN c.avg_monthly_bill > 60 THEN 'Opportunità Utilities: Spingere Comparazione Tariffe' 
        ELSE 'Cluster Standard' 
    END AS Strategia_Cross_Selling_Consigliata 
FROM churn_stats c 
LEFT JOIN stolen_stats s ON c.row_num = s.row_num;
```

---

## Data Visualizzation & BI (Power BI)
La vista SQL è stata agganciata direttamente a **Power BI Desktop** tramite un canale di connessione **ODBC**. La dashboard applica logiche avanzate di UI/UX finalizzate a massimizzare la leggibilità e la salienza visiva dei dati commerciali, adottando la palette cromatica istituzionale di Segugio.it (Verde Ottanio).

### Metriche KPI implementate in DAX:
Per garantire la massima precisione visiva ed evitare troncamenti o arrotondamenti grafici automatici (`K`), le metriche principali di sintesi sono state forzate via codice:
*   **Aree Analizzate:** `Totale_Aree = FORMAT(COUNT('market-insights'[Area_Geografica]), "#,##0")`
*   **Abbandono Medio:** `Churn_Medio = AVERAGE('market-insights'[Churn_Rate_Percentuale]) / 100` *(Formattato come %)*
*   **Risparmio Utenti:** `Risparmio_Potenziale_Totale = FORMAT(SUMX(FILTER('market-insights', 'market-insights'[Spesa_Media_Mensile] > 70), 'market-insights'[Spesa_Media_Mensile] * 0.15), "€ #,##0")`

---

## Business Insights & Impatto Strategico (Executive Summary)

I volumi emersi dall'aggregazione finale dei dati sul report delineano la conformazione del funnel di vendita e guidano le decisioni del CRM:

*   **Dominanza del Comparto Utilities (638 Cluster):** Oltre il 55% del mercato evidenzia utenti con spese fisse mensili elevate nelle utenze telefoniche ed energetiche. Questa è l'area a maggior volume transazionale per la piattaforma: spingere i funnel di comparazione tariffaria standard per generare lead veloci.
*   **Ottimizzazione della Retention (455 Cluster Standard):** Circa il 40% delle aree si attesta su livelli di rischio e spesa medi. Per questo segmento, la strategia raccomandata è il monitoraggio passivo e la fidelizzazione tramite newsletter periodiche basate sui prezzi di mercato (Osservatorio Tariffe).
*   **La Nicchia ad Alto Valore (10 Cluster Target Prioritario):** Costituiscono il segmento a massima redditività strategica. Unendo un elevato tasso di abbandono a un'alta sinistrosità automobilistica sul territorio, il marketing deve automatizzare l'invio di offerte cross-prodotto (*"Sconto RC Auto Furto/Incendio se attivi una tariffa Luce partner"*), ottimizzando il CAC (Costo di Acquisizione Cliente).
*   **Focus Insurtech Separato (3 Cluster):** Regioni caratterizzate da picchi storici di furti d'auto ma spesa utilities sotto la soglia critica. In queste aree la forza vendita deve focalizzarsi esclusivamente sulla vendita di polizze accessorie.
