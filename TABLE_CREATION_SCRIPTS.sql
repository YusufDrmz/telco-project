-- ============================================================
--  TABLE CREATION SCRIPTS
--  Telco Project - i2i Systems
--  Oracle XE
-- ============================================================


-- ------------------------------------------------------------
-- 1. TARIFFS
-- ------------------------------------------------------------
CREATE TABLE TARIFFS (
    TARIFF_ID    NUMBER(5)      PRIMARY KEY,
    NAME         VARCHAR2(100)  NOT NULL,
    MONTHLY_FEE  NUMBER(10,2)   NOT NULL,
    DATA_LIMIT   NUMBER(15,2)   DEFAULT 0,   -- MB cinsinden; 0 = limit yok/dahil değil
    MINUTE_LIMIT NUMBER(10)     DEFAULT 0,
    SMS_LIMIT    NUMBER(10)     DEFAULT 0
);

-- Index: tarife adına göre arama için
CREATE INDEX IDX_TARIFFS_NAME ON TARIFFS(NAME);


-- ------------------------------------------------------------
-- 2. CUSTOMERS
-- ------------------------------------------------------------
CREATE TABLE CUSTOMERS (
    CUSTOMER_ID  NUMBER(10)     PRIMARY KEY,
    NAME         VARCHAR2(100)  NOT NULL,
    CITY         VARCHAR2(100),
    SIGNUP_DATE  DATE           NOT NULL,
    TARIFF_ID    NUMBER(5)      NOT NULL,
    CONSTRAINT FK_CUSTOMERS_TARIFF
        FOREIGN KEY (TARIFF_ID) REFERENCES TARIFFS(TARIFF_ID)
);

-- Index: tarife bazlı sorgu performansı için
CREATE INDEX IDX_CUSTOMERS_TARIFF ON CUSTOMERS(TARIFF_ID);
-- Index: şehir dağılımı sorguları için
CREATE INDEX IDX_CUSTOMERS_CITY ON CUSTOMERS(CITY);
-- Index: kayıt tarihi sorguları için
CREATE INDEX IDX_CUSTOMERS_SIGNUP ON CUSTOMERS(SIGNUP_DATE);


-- ------------------------------------------------------------
-- 3. MONTHLY_STATS
-- ------------------------------------------------------------
CREATE TABLE MONTHLY_STATS (
    ID             NUMBER(10)    PRIMARY KEY,
    CUSTOMER_ID    NUMBER(10)    NOT NULL,
    DATA_USAGE     NUMBER(15,2)  DEFAULT 0,   -- MB cinsinden
    MINUTE_USAGE   NUMBER(10)    DEFAULT 0,
    SMS_USAGE      NUMBER(10)    DEFAULT 0,
    PAYMENT_STATUS VARCHAR2(20)  NOT NULL,
    CONSTRAINT FK_STATS_CUSTOMER
        FOREIGN KEY (CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
    CONSTRAINT CHK_PAYMENT_STATUS
        CHECK (PAYMENT_STATUS IN ('PAID', 'UNPAID', 'LATE'))
);

-- Index: müşteri bazlı sorgu performansı için
CREATE INDEX IDX_STATS_CUSTOMER ON MONTHLY_STATS(CUSTOMER_ID);
-- Index: ödeme durumu sorguları için
CREATE INDEX IDX_STATS_PAYMENT ON MONTHLY_STATS(PAYMENT_STATUS);
