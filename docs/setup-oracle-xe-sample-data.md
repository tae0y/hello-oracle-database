# Set Up Oracle XE Sample Data

This page describes how to install the HR sample schema using SQL Developer and run common SQL operations against it.

## Prerequisites

- Oracle XE container running and healthy
- [SQL Developer](https://www.oracle.com/database/sqldeveloper/) installed on the host machine
- HR schema scripts downloaded from [oracle-samples/db-sample-schemas](https://github.com/oracle-samples/db-sample-schemas) and extracted to a local folder

## Accounts and Privileges

This setup uses two database accounts. Each step below specifies which account to use.

| Account | Role | Purpose in this guide |
|---------|------|----------------------|
| SYSTEM | DBA (database administrator) | Create the HR user and grant privileges. Drop the HR user when removing. SYSTEM can create/drop any user and grant any privilege. |
| HR | Schema owner | Run DDL scripts and sample queries. HR owns the tables and has only the privileges needed: `CREATE SESSION`, `CREATE TABLE`, `CREATE SEQUENCE`, etc. |

Running queries as HR instead of SYSTEM follows the principle of least privilege. Dictionary views like `USER_TABLES` return only HR's 7 tables, not the hundreds of system tables visible to SYSTEM.

## Install the HR Schema

Oracle XE 21c does **not** include the HR schema. The official scripts create it from scratch.

### Step 1. Create the HR user (SYSTEM)

1. Open SQL Developer and create a connection for SYSTEM.

    | Field | Value |
    |-------|-------|
    | Connection Name | `XE - SYSTEM` |
    | Username | `system` |
    | Password | Value of `ORACLE_PWD` in `.env` |
    | Hostname | `localhost` |
    | Port | `1521` |
    | SID | `XE` |

1. Open a worksheet on the **XE - SYSTEM** connection and run the following.

    ```sql
    -- Create the HR user (change the password as needed)
    CREATE USER hr IDENTIFIED BY hr
                   DEFAULT TABLESPACE users
                   QUOTA UNLIMITED ON users;

    -- Grant the minimum privileges required by the schema scripts
    GRANT CREATE MATERIALIZED VIEW,
          CREATE PROCEDURE,
          CREATE SEQUENCE,
          CREATE SESSION,
          CREATE SYNONYM,
          CREATE TABLE,
          CREATE TRIGGER,
          CREATE TYPE,
          CREATE VIEW
      TO hr;
    ```

    SYSTEM is needed here because `CREATE USER` and `GRANT` are DBA-level operations. A regular user cannot create other users.

### Step 2. Run hr_create.sql (HR)

This script creates all tables, indexes, constraints, the `EMP_DETAILS_VIEW` view, and column comments.

1. Create a connection for HR.

    | Field | Value |
    |-------|-------|
    | Connection Name | `XE - HR` |
    | Username | `hr` |
    | Password | Password set in Step 1 (e.g. `hr`) |
    | Hostname | `localhost` |
    | Port | `1521` |
    | SID | `XE` |

1. Open `human_resources/hr_create.sql` in SQL Developer (**File > Open**).

1. Make sure the worksheet is connected to **XE - HR** (check the dropdown in the top-right of the worksheet).

1. Run the script with **F5** (Run Script), not Ctrl+Enter. F5 executes the entire file as a script, which is needed for multi-statement SQL files.

> **Important:** If the HR connection fails, try changing SID to Service Name `XEPDB1` in the connection settings. Repeat Step 1 against XEPDB1 as well.

### Step 3. Run hr_populate.sql (HR)

This script inserts seed data into all 7 tables. It temporarily disables the `dept_mgr_fk` constraint (circular FK between DEPARTMENTS and EMPLOYEES), inserts the data, then re-enables it.

1. Open `human_resources/hr_populate.sql` in SQL Developer.

1. Confirm the worksheet is connected to **XE - HR**.

1. Run the script with **F5**.

### Step 4. Run hr_code.sql (HR)

This script creates two procedures (`secure_dml`, `add_job_history`) and two triggers (`secure_employees`, `update_job_history`). The `secure_employees` trigger is created but immediately disabled — it blocks DML outside business hours and would interfere with practice queries.

1. Open `human_resources/hr_code.sql` in SQL Developer.

1. Confirm the worksheet is connected to **XE - HR**.

1. Run the script with **F5**.

### Step 5. Verify

Open a new worksheet on the **XE - HR** connection and run:

```sql
SELECT table_name FROM user_tables ORDER BY table_name;
```

Expected output:

| TABLE_NAME |
|------------|
| COUNTRIES |
| DEPARTMENTS |
| EMPLOYEES |
| JOBS |
| JOB_HISTORY |
| LOCATIONS |
| REGIONS |

Verify row counts match the expected data:

```sql
SELECT 'regions' AS table_name, COUNT(*) AS row_count FROM regions
UNION ALL SELECT 'countries',    COUNT(*) FROM countries
UNION ALL SELECT 'locations',    COUNT(*) FROM locations
UNION ALL SELECT 'departments',  COUNT(*) FROM departments
UNION ALL SELECT 'employees',    COUNT(*) FROM employees
UNION ALL SELECT 'jobs',         COUNT(*) FROM jobs
UNION ALL SELECT 'job_history',  COUNT(*) FROM job_history;
```

| TABLE_NAME | ROW_COUNT |
|------------|-----------|
| regions | 5 |
| countries | 25 |
| locations | 23 |
| departments | 27 |
| employees | 107 |
| jobs | 19 |
| job_history | 10 |

## HR Schema Overview

```
REGIONS ──< COUNTRIES ──< LOCATIONS ──< DEPARTMENTS ──< EMPLOYEES
                                                    └──< JOB_HISTORY ──> JOBS
```

| Table | Description |
|-------|-------------|
| REGIONS | Continents (Americas, Europe, Asia, etc.) |
| COUNTRIES | Countries per region |
| LOCATIONS | Office addresses with city and country |
| DEPARTMENTS | Company departments with manager and location FK |
| EMPLOYEES | All employees with salary, job, manager (self-referencing FK) |
| JOBS | Job titles with min/max salary ranges |
| JOB_HISTORY | Past positions held by employees (composite PK: employee_id + start_date) |

## Sample Queries

Run all queries below in a SQL Developer worksheet connected as **HR**. HR owns these tables, so no schema prefix is needed.

### SELECT

```sql
-- Employees earning above 10000, ordered by salary descending
SELECT employee_id, first_name, last_name, salary
FROM   employees
WHERE  salary > 10000
ORDER BY salary DESC;
```

### JOIN

```sql
-- Employee name, department, and office city (3-table join)
SELECT e.first_name, e.last_name, d.department_name, l.city
FROM   employees e
JOIN   departments d ON e.department_id = d.department_id
JOIN   locations l   ON d.location_id   = l.location_id
ORDER BY d.department_name, e.last_name;
```

```sql
-- Employee, manager name, and job title (self-join)
SELECT e.first_name || ' ' || e.last_name AS employee,
       m.first_name || ' ' || m.last_name AS manager,
       j.job_title
FROM   employees e
JOIN   employees m ON e.manager_id = m.employee_id
JOIN   jobs j      ON e.job_id     = j.job_id
ORDER BY manager, employee;
```

### GROUP BY

```sql
-- Headcount and average salary per department
SELECT d.department_name,
       COUNT(*)              AS headcount,
       ROUND(AVG(e.salary))  AS avg_salary
FROM   employees e
JOIN   departments d ON e.department_id = d.department_id
GROUP BY d.department_name
ORDER BY avg_salary DESC;
```

```sql
-- Departments with average salary above 8000
SELECT d.department_name,
       ROUND(AVG(e.salary)) AS avg_salary
FROM   employees e
JOIN   departments d ON e.department_id = d.department_id
GROUP BY d.department_name
HAVING AVG(e.salary) > 8000
ORDER BY avg_salary DESC;
```

### UPDATE

```sql
-- Give a 10% raise to employees in the IT department
UPDATE employees
SET    salary = salary * 1.10
WHERE  department_id = (
    SELECT department_id FROM departments WHERE department_name = 'IT'
);
```

### DELETE

```sql
-- Remove job history records before 2000
DELETE FROM job_history
WHERE  start_date < TO_DATE('2000-01-01', 'YYYY-MM-DD');
```

## Explicit Transaction Management

Oracle auto-commits DDL statements (CREATE, ALTER, DROP) but DML (INSERT, UPDATE, DELETE) requires an explicit commit. SQL Developer has **auto-commit off** by default. After running a DML statement, the change exists only in your session until you commit or rollback.

### COMMIT and ROLLBACK

```sql
-- Run an UPDATE (transaction starts implicitly)
UPDATE employees SET salary = salary * 1.05 WHERE department_id = 60;

-- Inspect the change (visible only in this session)
SELECT employee_id, salary FROM employees WHERE department_id = 60;
```

To persist the change, click the **Commit** button in the toolbar (or press F11). To discard it, click **Rollback** (or press F12).

```sql
-- Or use SQL statements directly
COMMIT;
-- or
ROLLBACK;
```

### SAVEPOINT

```sql
UPDATE employees SET salary = salary * 1.05 WHERE department_id = 60;
SAVEPOINT after_dept60;

UPDATE employees SET salary = salary * 1.03 WHERE department_id = 90;

-- Undo only the second update
ROLLBACK TO after_dept60;

-- The first update is still pending — commit or rollback
COMMIT;
```

### Read consistency

Oracle provides statement-level read consistency by default. Each query sees a snapshot of data as of the statement start time. Other sessions do not see uncommitted changes.

To observe this, open two separate worksheets to HR (right-click the HR connection > **Open SQL Worksheet** twice — each worksheet gets its own database session).

```sql
-- Worksheet A
UPDATE employees SET salary = 99999 WHERE employee_id = 100;
-- Do NOT commit
```

```sql
-- Worksheet B
SELECT salary FROM employees WHERE employee_id = 100;
-- Returns the original salary, not 99999
```

Worksheet B sees the original value because Worksheet A's uncommitted change is invisible to other sessions. After Worksheet A commits, Worksheet B's next query will see 99999.

## Remove

1. Open a worksheet on the **XE - SYSTEM** connection and run:

    ```sql
    DROP USER hr CASCADE;
    ```

    `CASCADE` drops the user and all objects (tables, indexes, procedures, triggers) owned by HR. Only a DBA can execute `DROP USER`.

1. Delete the **XE - HR** connection from SQL Developer.
