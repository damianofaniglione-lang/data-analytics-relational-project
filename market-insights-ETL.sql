-- =============================================================================
-- PIPELINE DI DATA ARCHITECTURE & ETL: PROGETTO SEGUGIO.IT
-- Autore: Data Analyst Portfolio
-- Descrizione: Creazione del Data Warehouse relazionale, pulizia dei dati grezzi 
--              e generazione della Core View di business per il Cross-Selling.
-- =============================================================================

-- 1️⃣ CREAZIONE E CONFIGURAZIONE DEL DATABASE
CREATE DATABASE IF NOT EXISTS segugio_relational_project;
USE segugio_relational_project;

-- Disattivazione temporanea dei vincoli per una ricostruzione pulita
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS fct_telecom_churn;
DROP TABLE IF EXISTS fct_stolen_vehicles;
DROP TABLE IF EXISTS dim_zipcode_population;
DROP TABLE IF EXISTS dim_make_details;
DROP TABLE IF EXISTS dim_locations;
SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 2️⃣ CREAZIONE DELLE STRUTTURE DELLE TABELLE (DATA MODELING)
-- =============================================================================

-- Tabella Dimensione: Località (Riallineata a 5 colonne reali)
CREATE TABLE dim_locations (
    Location_ID INT PRIMARY KEY,
    Region VARCHAR(100),
    Country VARCHAR(100),
    Population VARCHAR(50), -- Temporaneo VARCHAR per gestire formattazioni con virgole tipo "201,500"
    Density DECIMAL(10,2)
);

-- Tabella Dimensione: Dettagli Costruttore Auto
CREATE TABLE dim_make_details (
    Make_ID INT PRIMARY KEY,
    Make_Name VARCHAR(100),
    Vehicle_Type VARCHAR(100)
);

-- Tabella Dimensione: Popolazione per CAP
CREATE TABLE dim_zipcode_population (
    Zip_Code VARCHAR(20) PRIMARY KEY,
    Population INT
);

-- Tabella dei Fatti: Furti Veicoli (Riallineata a 8 colonne reali nell'ordine esatto del CSV)
CREATE TABLE fct_stolen_vehicles (
    Vehicle_ID INT PRIMARY KEY,
    Vehicle_Type VARCHAR(100),
    Make_ID INT,
    Model_Year INT,
    Vehicle_Desc VARCHAR(255),
    Vehicle_Color VARCHAR(50),
    Date_Stolen DATE, -- MySQL interpreterà nativamente il formato standard del server
    Location_ID INT,
    FOREIGN KEY (Make_ID) REFERENCES dim_make_details(Make_ID),
    FOREIGN KEY (Location_ID) REFERENCES dim_locations(Location_ID)
);

-- Tabella dei Fatti: Comportamento Consumatori Telecom (38 colonne allineate)
CREATE TABLE fct_telecom_churn (
    Customer_ID VARCHAR(50) PRIMARY KEY,
    Gender VARCHAR(20),
    Age INT,
    Married VARCHAR(10),
    Number_of_Dependents INT,
    City VARCHAR(100),
    Zip_Code VARCHAR(20),
    Latitude DECIMAL(10,6),
    Longitude DECIMAL(10,6),
    Number_of_Referrals INT,
    Tenure_in_Months INT,
    Offer VARCHAR(50),
    Phone_Service VARCHAR(10),
    Avg_Monthly_Long_Distance_Charges DECIMAL(10,2),
    Multiple_Lines VARCHAR(10),
    Internet_Service VARCHAR(10),
    Internet_Type VARCHAR(50),
    Avg_Monthly_GB_Download INT,
    Online_Security VARCHAR(10),
    Online_Backup VARCHAR(10),
    Device_Protection_Plan VARCHAR(10),
    Premium_Tech_Support VARCHAR(10),
    Streaming_TV VARCHAR(10),
    Streaming_Movies VARCHAR(10),
    Streaming_Music VARCHAR(10),
    Unlimited_Data VARCHAR(10),
    Contract VARCHAR(50),
    Paperless_Billing VARCHAR(10),
    Payment_Method VARCHAR(50),
    Monthly_Charge DECIMAL(10,2),
    Total_Charges DECIMAL(10,2), -- Diventerà numerico DECIMAL grazie alla pulizia condizionale in fase di load
    Total_Refunds DECIMAL(10,2),
    Total_Extra_Data_Charges DECIMAL(10,2),
    Total_Long_Distance_Charges DECIMAL(10,2),
    Total_Revenue DECIMAL(10,2),
    Customer_Status VARCHAR(50),
    Churn_Category VARCHAR(100),
    Churn_Reason VARCHAR(255),
    FOREIGN KEY (Zip_Code) REFERENCES dim_zipcode_population(Zip_Code)
);

-- =============================================================================
-- 3️⃣ DATA INGESTION & CLEANING ATTRAVERSO LA CARTELLA SICURA (SECURE_FILE_PRIV)
-- =============================================================================

SET FOREIGN_KEY_CHECKS = 0;

-- Caricamento 1: Locations (Risolve bug caratteri BOM di Excel)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/locations.csv' 
IGNORE INTO TABLE dim_locations 
CHARACTER SET utf8mb4 
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' 
IGNORE 1 LINES;

-- Caricamento 2: Make Details
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/make_details.csv' 
IGNORE INTO TABLE dim_make_details 
CHARACTER SET utf8mb4 
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' 
IGNORE 1 LINES;

-- Caricamento 3: Zipcode Population
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/telecom_zipcode_population.csv' 
IGNORE INTO TABLE dim_zipcode_population 
CHARACTER SET utf8mb4 
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' 
IGNORE 1 LINES;

-- Caricamento 4: Stolen Vehicles
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/stolen_vehicles.csv' 
IGNORE INTO TABLE fct_stolen_vehicles 
CHARACTER SET utf8mb4 
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' 
IGNORE 1 LINES;

-- Caricamento 5: Telecom Customer Churn (Risolve bug dei campi vuoti dei nuovi utenti in una variabile)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/telecom_customer_churn.csv' 
IGNORE INTO TABLE fct_telecom_churn 
CHARACTER SET utf8mb4 
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' 
IGNORE 1 LINES 
(Customer_ID, Gender, Age, Married, Number_of_Dependents, City, Zip_Code, Latitude, Longitude, Number_of_Referrals, Tenure_in_Months, Offer, Phone_Service, Avg_Monthly_Long_Distance_Charges, Multiple_Lines, Internet_Service, Internet_Type, Avg_Monthly_GB_Download, Online_Security, Online_Backup, Device_Protection_Plan, Premium_Tech_Support, Streaming_TV, Streaming_Movies, Streaming_Music, Unlimited_Data, Contract, Paperless_Billing, Payment_Method, Monthly_Charge, @raw_total_charges, Total_Refunds, Total_Extra_Data_Charges, Total_Long_Distance_Charges, Total_Revenue, Customer_Status, Churn_Category, Churn_Reason) 
SET Total_Charges = CASE WHEN TRIM(@raw_total_charges) = '' OR @raw_total_charges IS NULL THEN 0.00 ELSE CAST(TRIM(@raw_total_charges) AS DECIMAL(10,2)) END;

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 4️⃣ DATA TRANSFORMATION & MANIPULATION POST-CARICAMENTO
-- =============================================================================

-- Pulizia e conversione del campo Population di dim_locations (rimozione delle virgole interne del testo)
UPDATE dim_locations SET Population = REPLACE(Population, ',', '') WHERE Population IS NOT NULL;
ALTER TABLE dim_locations MODIFY COLUMN Population INT;

-- =============================================================================
-- 5️⃣ GENERAZIONE DELLA CORE ANALYTICAL VIEW (MARKET INSIGHTS PER POWER BI)
-- =============================================================================

CREATE OR REPLACE VIEW `market-insights` AS 
WITH stolen_stats AS ( 
    -- Aggregazione dei furti auto ordinati per massimo rischio territoriale
    SELECT l.Region, COUNT(s.Vehicle_ID) AS total_thefts, 
           ROW_NUMBER() OVER (ORDER BY COUNT(s.Vehicle_ID) DESC) AS row_num 
    FROM fct_stolen_vehicles s 
    JOIN dim_locations l ON s.Location_ID = l.Location_ID 
    GROUP BY l.Region 
), 
churn_stats AS ( 
    -- Aggregazione dei log comportamentali ordinati per spesa massima dell'utente
    SELECT City, COUNT(Customer_ID) AS total_customers, 
           SUM(CASE WHEN Customer_Status = 'Churned' THEN 1 ELSE 0 END) AS churned_customers, 
           AVG(Monthly_Charge) AS avg_monthly_bill, 
           ROW_NUMBER() OVER (ORDER BY AVG(Monthly_Charge) DESC) AS row_num 
    FROM fct_telecom_churn 
    GROUP BY City 
) 
-- Unione statistica surrogata posizionale per armonizzare i dati territoriali
SELECT 
    c.City AS Area_Geografica,
    c.total_customers AS Clienti_Totali,
    ROUND((c.churned_customers / c.total_customers) * 100, 2) AS Churn_Rate_Percentuale,
    ROUND(c.avg_monthly_bill, 2) AS Spesa_Media_Mensile,
    COALESCE(s.total_thefts, 0) AS Furti_Auto_Registrati, 
    -- Segmentazione CRM automatizzata basata sui KPI effettivi emersi nel report
    CASE 
        WHEN COALESCE(s.total_thefts, 0) >= 1 AND ROUND((c.churned_customers / c.total_customers) * 100, 2) > 15 THEN 'Target Prioritario: Alta Sinistrosità e Alto Abbandono' 
        WHEN COALESCE(s.total_thefts, 0) >= 1 THEN 'Opportunità Insurtech: Spingere Polizze Furto/Incendio' 
        WHEN c.avg_monthly_bill > 60 THEN 'Opportunità Utilities: Spingere Comparazione Tariffe' 
        ELSE 'Cluster Standard' 
    END AS Strategia_Cross_Selling_Consigliata 
FROM churn_stats c 
LEFT JOIN stolen_stats s ON c.row_num = s.row_num;

-- =============================================================================
-- TEST FINALE DI VALIDAZIONE DEI VOLUMI DEL DATA WAREHOUSE
-- =============================================================================
SELECT 'dim_locations' AS Tabella, COUNT(*) AS Record_Totali FROM dim_locations
UNION ALL SELECT 'dim_make_details', COUNT(*) FROM dim_make_details
UNION ALL SELECT 'dim_zipcode_population', COUNT(*) FROM dim_zipcode_population
UNION ALL SELECT 'fct_stolen_vehicles', COUNT(*) FROM fct_stolen_vehicles
UNION ALL SELECT 'fct_telecom_churn', COUNT(*) FROM fct_telecom_churn;
