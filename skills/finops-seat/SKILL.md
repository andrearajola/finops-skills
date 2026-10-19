---
name: finops-seat
description: Asistente de FinOps para Snowflake. Proporciona el modelo de datos, reglas de fechas, logica de creditos, y consultas comunes para reconciliacion y analisis de costes.
---

# FinOps Skill — SEAT (DATAGARAGE)

## About

Asistente de FinOps para la cuenta DATAGARAGE de SEAT en Snowflake. Este Skill proporciona a CoCo el conocimiento del modelo de datos de FinOps, las reglas de fechas, la logica de creditos, y las consultas mas comunes.

Idioma preferido: espanol. Ingles tambien OK.

Cuenta: DATAGARAGE
Bases de datos principales: PRO_BRONZE_DB (schema FINOPS), INFRA_DB (schema FINOPS_PRO)

---

## Modelo de datos

### Tablas de costes (destino — usar siempre para analisis)

Estas son las tablas que CoCo debe consultar. NUNCA consultar directamente las vistas de SNOWFLAKE.ACCOUNT_USAGE — los datos ya estan materializados aqui.

#### PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS
Costes de compute por warehouse y schema. Incluye filas de idle time y cloud services overhead.

| Columna | Tipo | Descripcion |
|---------|------|-------------|
| CLOUD_PROVIDER | VARCHAR | Siempre 'SNOWFLAKE' |
| ACCOUNT_LOCATOR | VARCHAR | ID de la cuenta |
| ACCOUNT_NAME | VARCHAR | Siempre 'DATAGARAGE' |
| DATE | DATE | Dia del consumo |
| CATEGORY | VARCHAR | 'Compute' |
| WAREHOUSE_NAME | VARCHAR | Nombre del warehouse |
| RESOURCE_TYPE | VARCHAR | 'SCHEMA', 'WAREHOUSE_METERING', 'COMPUTE_POOL' |
| RESOURCE_NAME | VARCHAR | Schema label, 'IDLE_TIME', 'CLOUD_SERVICES_WH_OPERATIONS', o nombre del compute pool |
| TOTAL_CREDITS | NUMBER | Creditos totales |
| COMPUTE_CREDITS | NUMBER | Creditos de compute |
| CLOUD_SERVICES_CREDITS | NUMBER | Creditos de cloud services |
| TST_BRONZE_LOAD_UTC | TIMESTAMP | Timestamp de carga |
| TST_BRONZE_LOAD_PID | VARCHAR | ID del batch de carga |

IMPORTANTE:
- Las filas con RESOURCE_TYPE = 'WAREHOUSE_METERING' y RESOURCE_NAME = 'IDLE_TIME' representan tiempo idle del warehouse. Excluir al sumar creditos por query.
- Las filas con RESOURCE_NAME = 'CLOUD_SERVICES_WH_OPERATIONS' representan overhead de cloud services del warehouse.
- Las filas con RESOURCE_TYPE = 'COMPUTE_POOL' vienen de SNOWPARK_CONTAINER_SERVICES_HISTORY.
- Para creditos por schema/query: filtrar RESOURCE_TYPE = 'SCHEMA'.

#### PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_ACCOUNT_CREDITS
Costes de servicios serverless, governance, data integration, y storage credits.

| Columna | Tipo | Descripcion |
|---------|------|-------------|
| CLOUD_PROVIDER | VARCHAR | Siempre 'SNOWFLAKE' |
| ACCOUNT_LOCATOR | VARCHAR | ID de la cuenta |
| ACCOUNT_NAME | VARCHAR | Siempre 'DATAGARAGE' |
| DATE | DATE | Dia del consumo |
| CATEGORY | VARCHAR | 'Serverless', 'Governance', 'Data Integration', 'Storage' |
| SERVICE_TYPE | VARCHAR | Tipo de servicio (PIPE, AUTO_CLUSTERING, SERVERLESS_TASK, etc.) |
| RESOURCE_TYPE | VARCHAR | 'PIPE', 'TABLE', 'TASK', 'SERVICE_TYPE' |
| RESOURCE_NAME | VARCHAR | Nombre del recurso |
| SCHEMA_LABEL | VARCHAR | Database.Schema (NULL si no aplica) |
| TOTAL_CREDITS | NUMBER | Creditos totales |
| COMPUTE_CREDITS | NUMBER | Creditos de compute |
| CLOUD_SERVICES_CREDITS | NUMBER | Creditos de cloud services |

IMPORTANTE: Esta tabla NO tiene columnas TST_BRONZE_LOAD_UTC ni TST_BRONZE_LOAD_PID.

#### PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_AI_CREDITS
Costes de servicios AI/ML (Cortex Agents, CoCo, AI Functions, Cortex Search, etc.)

| Columna | Tipo | Descripcion |
|---------|------|-------------|
| CLOUD_PROVIDER | VARCHAR | Siempre 'SNOWFLAKE' |
| ACCOUNT_LOCATOR | VARCHAR | ID de la cuenta |
| ACCOUNT_NAME | VARCHAR | Siempre 'DATAGARAGE' |
| DATE | DATE | Dia del consumo |
| CATEGORY | VARCHAR | 'AI/ML' |
| SERVICE_TYPE | VARCHAR | 'Cortex Agents', 'Document AI', 'Cortex AI Functions', 'Cortex Code Snowsight', 'Snowflake Intelligence', 'Cortex Code CLI', 'Cortex Analyst', 'Fine-Tuning', 'Provisioned Throughput', 'Cortex Search' |
| RESOURCE_TYPE | VARCHAR | 'USER' o 'SCHEMA' |
| OBJECT_NAME | VARCHAR | Nombre del usuario o recurso |
| TOTAL_CREDITS | NUMBER | Creditos totales |
| TOTAL_TOKENS | NUMBER | Tokens consumidos |
| TST_BRONZE_LOAD_UTC | TIMESTAMP | Timestamp de carga |
| TST_BRONZE_LOAD_PID | VARCHAR | ID del batch de carga |

#### PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_STORAGE
Costes de almacenamiento por schema y stage.

| Columna | Tipo | Descripcion |
|---------|------|-------------|
| CLOUD_PROVIDER | VARCHAR | Siempre 'SNOWFLAKE' |
| ACCOUNT_LOCATOR | VARCHAR | ID de la cuenta |
| ACCOUNT_NAME | VARCHAR | Siempre 'DATAGARAGE' |
| DATE | DATE | Dia del snapshot |
| CATEGORY | VARCHAR | 'Storage' |
| STORAGE_TYPE | VARCHAR | 'BLOCK_STORAGE' |
| RESOURCE_TYPE | VARCHAR | 'SCHEMA' o 'ACCOUNT' |
| RESOURCE_NAME | VARCHAR | Schema label o 'STAGE' |
| TOTAL_STORAGE_TB | DECIMAL | Total en TB |
| ACTIVE_TB | DECIMAL | Almacenamiento activo en TB |
| TIME_TRAVEL_TB | DECIMAL | Time travel en TB |
| FAILSAFE_TB | DECIMAL | Failsafe en TB |
| RETAINED_CLONE_TB | DECIMAL | Retained for clone en TB |
| TST_BRONZE_LOAD_UTC | TIMESTAMP | Timestamp de carga |
| TST_BRONZE_LOAD_PID | VARCHAR | ID del batch de carga |

#### PRO_BRONZE_DB.FINOPS.TAGS_DEFINITIONS
Tabla de tags para atribucion de costes. Cada objeto (schema, warehouse, usuario, compute pool) tiene tags de BU, UC, TOOL, PLATFORM.

| Columna | Tipo | Descripcion |
|---------|------|-------------|
| OBJECT_TYPE | VARCHAR | 'SCHEMA', 'USER', 'COMPUTE_POOL' |
| OBJECT_NAME | VARCHAR | Nombre completo del objeto (ej. 'DB.SCHEMA') |
| INSERTED_AT | TIMESTAMP | Cuando se inserto |
| BU | VARCHAR | Business Unit |
| UC | VARCHAR | Use Case |
| TOOL | VARCHAR | Herramienta |
| PLATFORM | VARCHAR | Siempre 'SNOWFLAKE' |

Nota: registros con BU/UC/TOOL = 'CHECK' necesitan ser clasificados por el equipo.

Para enriquecer los datos de costes con tags:
```sql
SELECT c.*, t.BU, t.UC, t.TOOL
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS c
LEFT JOIN PRO_BRONZE_DB.FINOPS.TAGS_DEFINITIONS t
  ON t.OBJECT_TYPE = 'SCHEMA'
  AND t.OBJECT_NAME = c.RESOURCE_NAME
WHERE c.RESOURCE_TYPE = 'SCHEMA';
```

#### INFRA_DB.FINOPS_PRO.DIM_DATES
Tabla de calendario con offsets relativos al dia actual.

| Columna | Tipo | Descripcion |
|---------|------|-------------|
| CALENDAR_DATE | DATE | Fecha |
| DAYS_OFFSET | NUMBER | Dias desde hoy (0 = hoy, 1 = ayer) |
| WEEKS_OFFSET | NUMBER | Semanas desde la semana actual |
| MONTHS_OFFSET | NUMBER | Meses desde el mes actual |
| IS_CURRENT_DAY | BOOLEAN | Es hoy? |
| IS_CURRENT_WEEK | BOOLEAN | Es esta semana? |
| IS_CURRENT_MONTH | BOOLEAN | Es este mes? |
| IS_CURRENT_QUARTER | BOOLEAN | Es este trimestre? |
| IS_CURRENT_YEAR | BOOLEAN | Es este ano? |

### Tablas fuente (INFRA_DB.FINOPS_PRO — solo referencia)

Estas tablas son las fuentes que el SP materializa. NO consultar directamente para analisis — usar las tablas de costes de arriba.

- METERING_HISTORY — fuente para ACCOUNT_CREDITS (servicios serverless, governance, etc.)
- WAREHOUSE_METERING_HISTORY — fuente para overhead y idle time
- QUERY_HISTORY — fuente para cloud services por query (latencia ~45 min)
- QUERY_ATTRIBUTION_HISTORY — fuente para creditos atribuidos por query (latencia ~3 horas)
- SNOWPARK_CONTAINER_SERVICES_HISTORY — fuente para compute pools
- RV_FINOPS_AIML_UNION — vista union de todos los servicios AI/ML
- RV_FINOPS_SCHEMA_COST_BASE — creditos de compute por schema
- RV_FINOPS_SCHEMA_STORAGE — storage por schema
- RV_FINOPS_STORAGE_ACCOUNT — storage a nivel cuenta (stages)
- SCHEMATA — lista de schemas (para TAGS_DEFINITIONS)
- USERS — lista de usuarios (para TAGS_DEFINITIONS)

---

## Reglas de fechas

| Caso de uso | Regla | Ejemplo de filtro | Por que |
|-------------|-------|-------------------|---------|
| Conciliacion mensual / comparacion con factura | Solo meses completos. NUNCA incluir el mes actual. | `WHERE DATE >= '2026-08-01' AND DATE <= '2026-08-31'` | La factura cubre meses completos. Datos parciales siempre mostraran diferencia. |
| Preguntas operativas diarias (top warehouses, quien ejecuto que) | Hasta ayer (CURRENT_DATE - 1) | `WHERE DATE <= DATEADD('day', -1, CURRENT_DATE())` | QUERY_HISTORY (~45 min) y QUERY_ATTRIBUTION_HISTORY (~3h) tienen latencias diferentes. Los datos de ayer estan completos para ambas. |
| Tendencias ad-hoc (esta subiendo el uso?) | Hoy esta bien para direccion general | `WHERE DATE <= CURRENT_DATE()` | Datos parciales son aceptables para ver patrones, no para reconciliar creditos exactos. |
| Comparacion de creditos entre QUERY_HISTORY y QUERY_ATTRIBUTION_HISTORY | Usar datos de hace 2+ dias | `WHERE DATE <= DATEADD('day', -2, CURRENT_DATE())` | Asegura que ambas vistas han materializado completamente. |

IMPORTANTE: Cuando el usuario pida "analisis de fin de mes", "comparar con la factura", o "reconciliacion", SIEMPRE usar meses completos. Cuando pregunte "que paso hoy" o "que esta pasando ahora", los datos de hoy estan bien.

---

## Logica de creditos

### Como sumar creditos totales de un periodo

Para el total de creditos de un mes:
```sql
WITH compute AS (
    SELECT SUM(TOTAL_CREDITS) AS credits
    FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS
    WHERE DATE BETWEEN '2026-08-01' AND '2026-08-31'
      AND RESOURCE_TYPE = 'SCHEMA'  -- excluir IDLE_TIME y CLOUD_SERVICES_WH_OPERATIONS
),
account AS (
    SELECT SUM(TOTAL_CREDITS) AS credits
    FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_ACCOUNT_CREDITS
    WHERE DATE BETWEEN '2026-08-01' AND '2026-08-31'
),
ai AS (
    SELECT SUM(TOTAL_CREDITS) AS credits
    FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_AI_CREDITS
    WHERE DATE BETWEEN '2026-08-01' AND '2026-08-31'
)
SELECT
    compute.credits AS compute_credits,
    account.credits AS account_credits,
    ai.credits AS ai_credits,
    COALESCE(compute.credits, 0) + COALESCE(account.credits, 0) + COALESCE(ai.credits, 0) AS total_credits
FROM compute, account, ai;
```

Nota: STORAGE se mide en TB, no en creditos. Para pasarlo a EUR usar la tarifa `TB/MES` de USAGE_UNITS_COST y CURRENCY_EXCHANGE (ver consulta 9).

### Conversion a EUR (todas las categorias)

| Categoria | Tabla | Unidad | Tarifa (USAGE_UNITS_COST.UNITS_OF_USAGE) |
|-----------|-------|--------|------------------------------------------|
| Compute | SNOWFLAKE_COST_CREDITS | Creditos | `CREDIT` |
| Serverless / Governance / Data Integration | SNOWFLAKE_COST_ACCOUNT_CREDITS | Creditos | `CREDIT` |
| AI/ML | SNOWFLAKE_COST_AI_CREDITS | Creditos | `IA_CREDIT` |
| Storage | SNOWFLAKE_COST_STORAGE | TB (snapshot diario) | `TB/MES` |

Formula: `cantidad x UNITS_OF_USAGE_COST (USD) x CURRENCY_DESTINATION_AMT (USD->EUR)`.
Tipo de cambio: `CURRENCY_EXCHANGE WHERE CURRENCY_ORIGIN = 'USD' AND CURRENCY_DESTINATION = 'EUR' AND fecha BETWEEN START_DATE AND END_DATE`.
Storage: la tarifa es mensual -> para un mes usar el TB medio del mes; para N dias, TB medio x tarifa x N/30.

### Comparacion con factura de Snowflake

La factura de Snowflake incluye:
- Creditos de compute (warehouses)
- Creditos de servicios serverless
- Creditos de cloud services
- Creditos de AI/ML
- Almacenamiento (en TB, facturado aparte)

Para comparar:
1. Sumar las 3 tablas de creditos (COST_CREDITS + COST_ACCOUNT_CREDITS + COST_AI_CREDITS) para el mes completo
2. Comparar con el total de creditos de la factura
3. La diferencia deberia ser minima (< 1%) si los datos estan completos

Fuentes de discrepancia posibles:
- Mes incompleto (datos parciales)
- Creditos de cloud services que no superan el 10% del total (Snowflake solo cobra el exceso)
- Ajustes o creditos de soporte aplicados por Snowflake

---

## Consultas de ejemplo

### 1. Resumen mensual de creditos por categoria
```sql
SELECT
    DATE_TRUNC('month', DATE) AS mes,
    'Compute' AS categoria,
    ROUND(SUM(TOTAL_CREDITS), 2) AS creditos
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS
WHERE DATE >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
  AND DATE < DATE_TRUNC('month', CURRENT_DATE())
  AND RESOURCE_TYPE = 'SCHEMA'
GROUP BY 1
UNION ALL
SELECT
    DATE_TRUNC('month', DATE),
    CATEGORY,
    ROUND(SUM(TOTAL_CREDITS), 2)
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_ACCOUNT_CREDITS
WHERE DATE >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
  AND DATE < DATE_TRUNC('month', CURRENT_DATE())
GROUP BY 1, 2
UNION ALL
SELECT
    DATE_TRUNC('month', DATE),
    'AI/ML',
    ROUND(SUM(TOTAL_CREDITS), 2)
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_AI_CREDITS
WHERE DATE >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
  AND DATE < DATE_TRUNC('month', CURRENT_DATE())
GROUP BY 1
ORDER BY 1, 2;
```

### 2. Top 10 warehouses por coste (ultimos 30 dias)
```sql
SELECT
    WAREHOUSE_NAME,
    ROUND(SUM(TOTAL_CREDITS), 2) AS total_credits,
    ROUND(SUM(COMPUTE_CREDITS), 2) AS compute_credits,
    ROUND(SUM(CLOUD_SERVICES_CREDITS), 2) AS cloud_credits
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS
WHERE DATE > DATEADD('day', -30, CURRENT_DATE())
  AND RESOURCE_TYPE = 'SCHEMA'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 10;
```

### 3. Creditos diarios de AI por servicio
```sql
SELECT
    DATE,
    SERVICE_TYPE,
    ROUND(SUM(TOTAL_CREDITS), 4) AS credits,
    SUM(TOTAL_TOKENS) AS tokens
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_AI_CREDITS
WHERE DATE > DATEADD('day', -14, CURRENT_DATE())
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;
```

### 4. Analisis de tiempo idle por warehouse
```sql
SELECT
    DATE,
    WAREHOUSE_NAME,
    ROUND(SUM(TOTAL_CREDITS), 4) AS idle_credits
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS
WHERE RESOURCE_NAME = 'IDLE_TIME'
  AND DATE > DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1, 2
ORDER BY 3 DESC;
```

### 5. Tendencia de storage por schema (ultimos 30 dias)
```sql
SELECT
    DATE,
    RESOURCE_NAME AS schema_name,
    ROUND(TOTAL_STORAGE_TB * 1024, 2) AS storage_gb
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_STORAGE
WHERE RESOURCE_TYPE = 'SCHEMA'
  AND DATE > DATEADD('day', -30, CURRENT_DATE())
ORDER BY 3 DESC;
```

### 6. Comparacion mes a mes
```sql
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', DATE) AS mes,
        ROUND(SUM(TOTAL_CREDITS), 2) AS credits
    FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS
    WHERE DATE >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
      AND DATE < DATE_TRUNC('month', CURRENT_DATE())
      AND RESOURCE_TYPE = 'SCHEMA'
    GROUP BY 1
)
SELECT
    mes,
    credits,
    LAG(credits) OVER (ORDER BY mes) AS mes_anterior,
    ROUND(credits - LAG(credits) OVER (ORDER BY mes), 2) AS cambio,
    ROUND((credits - LAG(credits) OVER (ORDER BY mes)) / NULLIF(LAG(credits) OVER (ORDER BY mes), 0) * 100, 1) AS cambio_pct
FROM monthly
ORDER BY 1;
```

### 7. Reconciliacion: total FinOps vs esperado
```sql
-- Reemplazar fechas con el mes a reconciliar
WITH finops_total AS (
    SELECT
        COALESCE(SUM(c.credits), 0) + COALESCE(SUM(a.credits), 0) + COALESCE(SUM(ai.credits), 0) AS total
    FROM
        (SELECT SUM(TOTAL_CREDITS) AS credits FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_CREDITS WHERE DATE BETWEEN '2026-08-01' AND '2026-08-31' AND RESOURCE_TYPE = 'SCHEMA') c,
        (SELECT SUM(TOTAL_CREDITS) AS credits FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_ACCOUNT_CREDITS WHERE DATE BETWEEN '2026-08-01' AND '2026-08-31') a,
        (SELECT SUM(TOTAL_CREDITS) AS credits FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_AI_CREDITS WHERE DATE BETWEEN '2026-08-01' AND '2026-08-31') ai
)
SELECT
    total AS finops_credits,
    NULL AS invoice_credits,  -- Antonio rellena con el valor de la factura
    NULL AS delta
FROM finops_total;
```

### 8. Cobertura de tags: objetos sin BU/UC asignado
```sql
SELECT
    OBJECT_TYPE,
    OBJECT_NAME,
    BU, UC, TOOL
FROM PRO_BRONZE_DB.FINOPS.TAGS_DEFINITIONS
WHERE BU = 'CHECK' OR UC = 'CHECK'
ORDER BY OBJECT_TYPE, OBJECT_NAME;
```

### 9. Coste de storage en EUR por mes (reconciliacion con factura)
```sql
-- TB medio del mes x tarifa TB/MES x tipo de cambio USD->EUR
WITH tarifa AS (
    SELECT UNITS_OF_USAGE_COST AS P
    FROM PRO_BRONZE_DB.FINOPS.USAGE_UNITS_COST
    WHERE UNITS_OF_USAGE = 'TB/MES' AND PLATFORM = 'SNOWFLAKE'
),
fx AS (
    SELECT CURRENCY_DESTINATION_AMT AS R, START_DATE, END_DATE
    FROM PRO_BRONZE_DB.FINOPS.CURRENCY_EXCHANGE
    WHERE CURRENCY_ORIGIN = 'USD' AND CURRENCY_DESTINATION = 'EUR'
),
diario AS (
    SELECT DATE, SUM(TOTAL_STORAGE_TB) AS TB   -- schemas + stages (RESOURCE_TYPE SCHEMA y ACCOUNT)
    FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_STORAGE
    WHERE DATE >= DATEADD('month', -3, DATE_TRUNC('month', CURRENT_DATE()))
      AND DATE <  DATE_TRUNC('month', CURRENT_DATE())   -- solo meses completos
    GROUP BY DATE
)
SELECT
    DATE_TRUNC('month', d.DATE)           AS mes,
    ROUND(AVG(d.TB), 4)                   AS tb_medio,
    ROUND(AVG(d.TB) * MAX(t.P), 2)        AS storage_usd,
    ROUND(AVG(d.TB) * MAX(t.P) * MAX(fx.R), 2) AS storage_eur
FROM diario d
CROSS JOIN tarifa t
JOIN fx ON LAST_DAY(d.DATE) BETWEEN fx.START_DATE AND fx.END_DATE
GROUP BY 1
ORDER BY 1;
```

Para comparar con la factura: `SNOWFLAKE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY WHERE SERVICE_TYPE = 'STORAGE'` (en USD). Comparar con `storage_usd`.

---

## Learning — Uso de CoCo con FinOps

### Que es CoCo?

CoCo (Cortex Code) es el IDE de Snowflake que permite interactuar con datos usando lenguaje natural. Con el FinOps Skill instalado, CoCo ya conoce el modelo de datos de FinOps y puede generar consultas sobre costes sin necesidad de conocer SQL.

### Procedimientos comunes con CoCo

#### 1. Analisis de costes por BU
Pregunta a CoCo: *"Cuanto ha gastado el BU P en compute en los ultimos 30 dias?"*

CoCo usara SNOWFLAKE_COST_CREDITS + TAGS_DEFINITIONS para filtrar por BU = 'P' y sumar creditos.

#### 2. Identificar picos de consumo
Pregunta: *"Cual es el warehouse con mayor consumo esta semana?"*

CoCo consultara SNOWFLAKE_COST_CREDITS agrupando por WAREHOUSE_NAME.

#### 3. Seguimiento de AI/ML
Pregunta: *"Dame el desglose de creditos AI por servicio del ultimo mes"*

CoCo consultara SNOWFLAKE_COST_AI_CREDITS agrupando por SERVICE_TYPE. Aqui tambien se ve el consumo de CoCo (SERVICE_TYPE = 'Cortex Code Snowsight' o 'Cortex Code CLI').

#### 4. Cobertura de tags
Pregunta: *"Que objetos tienen BU = CHECK?"*

CoCo consultara TAGS_DEFINITIONS para encontrar recursos sin clasificar.

#### 5. Conversion a EUR
Pregunta: *"Cuanto hemos gastado en total en EUR el mes pasado?"*

CoCo aplicara la cadena de conversion: creditos x precio por credito (USAGE_UNITS_COST) x tipo de cambio (CURRENCY_EXCHANGE).

### Como instalar el Skill en CoCo

El Skill se publica como Cortex Extension. Para habilitarlo en tu sesion de CoCo:
1. Abre CoCo (Snowsight o Desktop)
2. Busca el skill `finops-seat` en el catalogo
3. Instalalo — a partir de ese momento CoCo conoce el modelo de datos de FinOps

### Monitorizar el uso de CoCo

El consumo de CoCo se registra en `PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_AI_CREDITS` con:
- `SERVICE_TYPE = 'Cortex Code Snowsight'` — uso desde Snowsight
- `SERVICE_TYPE = 'Cortex Code CLI'` — uso desde Desktop/CLI
- `RESOURCE_TYPE = 'USER'` — con OBJECT_NAME = nombre del usuario

```sql
SELECT
    DATE,
    SERVICE_TYPE,
    OBJECT_NAME AS usuario,
    ROUND(SUM(TOTAL_CREDITS), 4) AS credits,
    SUM(TOTAL_TOKENS) AS tokens
FROM PRO_BRONZE_DB.FINOPS.SNOWFLAKE_COST_AI_CREDITS
WHERE SERVICE_TYPE IN ('Cortex Code Snowsight', 'Cortex Code CLI')
  AND DATE > DATEADD('day', -30, CURRENT_DATE())
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 4 DESC;
```

---

## Notas y particularidades

1. **SNOWFLAKE_COST_ACCOUNT_CREDITS** NO tiene columnas TST_BRONZE_LOAD_UTC ni TST_BRONZE_LOAD_PID. Las otras 3 tablas de costes si las tienen.

2. **Filas de IDLE_TIME y CLOUD_SERVICES_WH_OPERATIONS** en SNOWFLAKE_COST_CREDITS: representan overhead del warehouse, no creditos por queries. Excluirlas al calcular coste por query o por schema. Incluirlas al calcular coste total del warehouse.

3. **Los datos se cargan una vez al dia** via SP_REFRESH_FINOPS_CACHE (watermark, limitado a ayer). No hay datos de hoy en las tablas de costes para las vistas que dependen de QUERY_HISTORY y QUERY_ATTRIBUTION_HISTORY.

4. **COMPUTE_POOL rows** en COST_CREDITS vienen de SNOWPARK_CONTAINER_SERVICES_HISTORY. Tienen RESOURCE_TYPE = 'COMPUTE_POOL'.

5. **Cloud services credit adjustment**: Snowflake solo cobra cloud services que excedan el 10% del total de compute diario. Las tablas de FinOps muestran el bruto. La factura puede mostrar menos por este ajuste.

6. **TAGS_DEFINITIONS con 'CHECK'**: registros nuevos se insertan con BU/UC/TOOL = 'CHECK'. Esto indica que el equipo necesita clasificarlos. Usar la query 8 para encontrar objetos sin clasificar.

<!-- POC Git-native CI/CD: deployed via Snowflake Git integration (2026-10-19) -->
