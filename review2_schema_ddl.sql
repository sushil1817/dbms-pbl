-- ============================================================================
-- DBMS PROJECT 41: CAMPUS FACILITY MAINTENANCE REQUEST MANAGEMENT SYSTEM
-- REVIEW 2: DDL SCHEMA WITH INTEGRITY CONSTRAINTS, CHECKS & TRIGGERS
-- Normalized up to Third Normal Form (3NF)   |   Target: MySQL 8.0.16+
-- ============================================================================

DROP DATABASE IF EXISTS CampusMaintenanceReview2;
CREATE DATABASE CampusMaintenanceReview2;
USE CampusMaintenanceReview2;

-- ----------------------------------------------------------------------------
-- 1. BUILDING
-- ----------------------------------------------------------------------------
CREATE TABLE Building (
    BuildingID   INT AUTO_INCREMENT PRIMARY KEY,
    BuildingCode VARCHAR(10)  NOT NULL UNIQUE,
    BuildingName VARCHAR(100) NOT NULL UNIQUE,
    Floors       INT NOT NULL CHECK (Floors > 0)
);

-- ----------------------------------------------------------------------------
-- 2. ROOM  (building of a request is derived through Room -> no redundancy)
-- ----------------------------------------------------------------------------
CREATE TABLE Room (
    RoomID     INT AUTO_INCREMENT PRIMARY KEY,
    BuildingID INT NOT NULL,
    RoomNo     VARCHAR(20) NOT NULL,
    FloorNo    INT NOT NULL CHECK (FloorNo >= 0),
    RoomType   VARCHAR(40) NOT NULL,
    FOREIGN KEY (BuildingID) REFERENCES Building(BuildingID) ON DELETE RESTRICT,
    UNIQUE (BuildingID, RoomNo)
);

-- ----------------------------------------------------------------------------
-- 3. ASSET
-- ----------------------------------------------------------------------------
CREATE TABLE Asset (
    AssetID     INT AUTO_INCREMENT PRIMARY KEY,
    RoomID      INT NOT NULL,
    AssetTag    VARCHAR(20)  NOT NULL UNIQUE,
    AssetName   VARCHAR(80)  NOT NULL,
    InstalledOn DATE,
    FOREIGN KEY (RoomID) REFERENCES Room(RoomID) ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- 4. CAMPUS_USER  (requesters and facility-office staff)
-- ----------------------------------------------------------------------------
CREATE TABLE Campus_User (
    UserID   INT AUTO_INCREMENT PRIMARY KEY,
    FullName VARCHAR(100) NOT NULL,
    Email    VARCHAR(120) NOT NULL UNIQUE,
    Phone    VARCHAR(15),
    Role     VARCHAR(20)  NOT NULL CHECK (Role IN ('Student','Faculty','Staff','Admin'))
);

-- ----------------------------------------------------------------------------
-- 5. CATEGORY and 6. PRIORITY
-- ----------------------------------------------------------------------------
CREATE TABLE Category (
    CategoryID   INT AUTO_INCREMENT PRIMARY KEY,
    CategoryName VARCHAR(50) NOT NULL UNIQUE
);

CREATE TABLE Priority (
    PriorityID   INT AUTO_INCREMENT PRIMARY KEY,
    PriorityName VARCHAR(20) NOT NULL UNIQUE,
    TargetHours  INT NOT NULL CHECK (TargetHours > 0)      -- response-time SLA
);

-- ----------------------------------------------------------------------------
-- 7. TECHNICIAN  (MaxActiveJobs drives the assignment-control trigger)
-- ----------------------------------------------------------------------------
CREATE TABLE Technician (
    TechID        INT AUTO_INCREMENT PRIMARY KEY,
    FullName      VARCHAR(100) NOT NULL,
    Phone         VARCHAR(15),
    CategoryID    INT NOT NULL,                             -- speciality
    MaxActiveJobs INT NOT NULL DEFAULT 3 CHECK (MaxActiveJobs > 0),
    IsActive      TINYINT(1) NOT NULL DEFAULT 1 CHECK (IsActive IN (0,1)),
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID) ON DELETE RESTRICT
);

-- ----------------------------------------------------------------------------
-- 8. STATUS_TRANSITION  (data-driven state machine; read by trigger)
-- ----------------------------------------------------------------------------
CREATE TABLE Status_Transition (
    FromStatus VARCHAR(20) NOT NULL,
    ToStatus   VARCHAR(20) NOT NULL,
    PRIMARY KEY (FromStatus, ToStatus)
);

-- ----------------------------------------------------------------------------
-- 9. MAINTENANCE_REQUEST
--    Rules: unique request number (+ format), closure details required,
--           ClosedAt only when Closed, ClosedAt not before CreatedAt.
-- ----------------------------------------------------------------------------
CREATE TABLE Maintenance_Request (
    RequestID      INT AUTO_INCREMENT PRIMARY KEY,
    RequestNo      VARCHAR(13) NOT NULL UNIQUE,
    RequesterID    INT NOT NULL,
    RoomID         INT NOT NULL,
    AssetID        INT NULL,
    CategoryID     INT NOT NULL,
    PriorityID     INT NOT NULL,
    Description    VARCHAR(255) NOT NULL,
    CreatedAt      DATETIME NOT NULL,
    Status         VARCHAR(20) NOT NULL DEFAULT 'Open',
    ClosedAt       DATETIME NULL,
    ClosureRemarks VARCHAR(255) NULL,                       -- closure / cancellation reason
    FOREIGN KEY (RequesterID) REFERENCES Campus_User(UserID),
    FOREIGN KEY (RoomID)      REFERENCES Room(RoomID),
    FOREIGN KEY (AssetID)     REFERENCES Asset(AssetID),
    FOREIGN KEY (CategoryID)  REFERENCES Category(CategoryID),
    FOREIGN KEY (PriorityID)  REFERENCES Priority(PriorityID),
    CONSTRAINT chk_req_no_format CHECK (RequestNo LIKE 'REQ-____-____'),
    CONSTRAINT chk_req_status CHECK (Status IN
        ('Open','Assigned','In Progress','On Hold','Resolved','Closed','Cancelled')),
    CONSTRAINT chk_closure_details CHECK
        (Status <> 'Closed' OR (ClosedAt IS NOT NULL AND ClosureRemarks IS NOT NULL
                                AND CHAR_LENGTH(TRIM(ClosureRemarks)) > 0)),
    CONSTRAINT chk_closedat_only_closed CHECK (Status = 'Closed' OR ClosedAt IS NULL),
    CONSTRAINT chk_closed_after_created CHECK (ClosedAt IS NULL OR ClosedAt >= CreatedAt)
);

-- ----------------------------------------------------------------------------
-- 10. ASSIGNMENT
-- ----------------------------------------------------------------------------
CREATE TABLE Assignment (
    AssignmentID INT AUTO_INCREMENT PRIMARY KEY,
    RequestID    INT NOT NULL,
    TechID       INT NOT NULL,
    AssignedAt   DATETIME NOT NULL,
    CompletedAt  DATETIME NULL,
    Status       VARCHAR(12) NOT NULL DEFAULT 'Active',
    FOREIGN KEY (RequestID) REFERENCES Maintenance_Request(RequestID) ON DELETE CASCADE,
    FOREIGN KEY (TechID)    REFERENCES Technician(TechID),
    CONSTRAINT chk_asg_status CHECK (Status IN ('Active','Completed','Reassigned')),
    CONSTRAINT chk_asg_done CHECK
        ((Status = 'Active' AND CompletedAt IS NULL) OR (Status <> 'Active' AND CompletedAt IS NOT NULL)),
    CONSTRAINT chk_asg_dates CHECK (CompletedAt IS NULL OR CompletedAt >= AssignedAt)
);

-- ----------------------------------------------------------------------------
-- 11. WORK_LOG
-- ----------------------------------------------------------------------------
CREATE TABLE Work_Log (
    LogID        INT AUTO_INCREMENT PRIMARY KEY,
    AssignmentID INT NOT NULL,
    LogTime      DATETIME NOT NULL,
    WorkNotes    VARCHAR(255) NOT NULL,
    HoursSpent   DECIMAL(4,2) NOT NULL CHECK (HoursSpent >= 0 AND HoursSpent <= 24),
    FOREIGN KEY (AssignmentID) REFERENCES Assignment(AssignmentID) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 12. MATERIAL  (stock can never go negative)
-- ----------------------------------------------------------------------------
CREATE TABLE Material (
    MaterialID   INT AUTO_INCREMENT PRIMARY KEY,
    MaterialName VARCHAR(80) NOT NULL UNIQUE,
    Unit         VARCHAR(15) NOT NULL,
    UnitCost     DECIMAL(10,2) NOT NULL CHECK (UnitCost >= 0),
    StockQty     INT NOT NULL CHECK (StockQty >= 0),
    ReorderLevel INT NOT NULL DEFAULT 0 CHECK (ReorderLevel >= 0)
);

-- ----------------------------------------------------------------------------
-- 13. MATERIAL_USAGE  (UnitCost = price snapshot at time of use)
-- ----------------------------------------------------------------------------
CREATE TABLE Material_Usage (
    UsageID    INT AUTO_INCREMENT PRIMARY KEY,
    LogID      INT NOT NULL,
    MaterialID INT NOT NULL,
    Quantity   INT NOT NULL CHECK (Quantity > 0),
    UnitCost   DECIMAL(10,2) NOT NULL CHECK (UnitCost >= 0),
    FOREIGN KEY (LogID)      REFERENCES Work_Log(LogID) ON DELETE CASCADE,
    FOREIGN KEY (MaterialID) REFERENCES Material(MaterialID)
);

-- ----------------------------------------------------------------------------
-- 14. REQUEST_COST  (labour / vendor / other charges; material cost is derived)
-- ----------------------------------------------------------------------------
CREATE TABLE Request_Cost (
    CostID      INT AUTO_INCREMENT PRIMARY KEY,
    RequestID   INT NOT NULL,
    CostType    VARCHAR(10) NOT NULL CHECK (CostType IN ('Labour','Vendor','Other')),
    Amount      DECIMAL(10,2) NOT NULL CHECK (Amount >= 0),
    Remarks     VARCHAR(120),
    FOREIGN KEY (RequestID) REFERENCES Maintenance_Request(RequestID) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- 15. STATUS_HISTORY  (written only by triggers)
-- ----------------------------------------------------------------------------
CREATE TABLE Status_History (
    HistoryID INT AUTO_INCREMENT PRIMARY KEY,
    RequestID INT NOT NULL,
    OldStatus VARCHAR(20) NULL,
    NewStatus VARCHAR(20) NOT NULL,
    ChangedAt DATETIME NOT NULL,
    ChangedBy INT NULL,
    FOREIGN KEY (RequestID) REFERENCES Maintenance_Request(RequestID) ON DELETE CASCADE,
    FOREIGN KEY (ChangedBy) REFERENCES Campus_User(UserID) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- 16. FEEDBACK  (one per request, rating 1-5)
-- ----------------------------------------------------------------------------
CREATE TABLE Feedback (
    FeedbackID  INT AUTO_INCREMENT PRIMARY KEY,
    RequestID   INT NOT NULL UNIQUE,
    Rating      INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Comments    VARCHAR(255),
    SubmittedAt DATETIME NOT NULL,
    FOREIGN KEY (RequestID) REFERENCES Maintenance_Request(RequestID) ON DELETE CASCADE
);

-- ----------------------------------------------------------------------------
-- INDEXES for frequently searched attributes (foreign keys are indexed by InnoDB)
-- ----------------------------------------------------------------------------
CREATE INDEX idx_req_status_priority ON Maintenance_Request (Status, PriorityID);
CREATE INDEX idx_req_created         ON Maintenance_Request (CreatedAt);
CREATE INDEX idx_asg_tech_status     ON Assignment (TechID, Status);
CREATE INDEX idx_hist_req_time       ON Status_History (RequestID, ChangedAt);

-- ----------------------------------------------------------------------------
-- STATE MACHINE DATA: the only legal status moves
-- ----------------------------------------------------------------------------
INSERT INTO Status_Transition (FromStatus, ToStatus) VALUES
('Open','Assigned'),        ('Open','Cancelled'),
('Assigned','In Progress'), ('Assigned','Open'),
('Assigned','On Hold'),     ('Assigned','Cancelled'),
('In Progress','On Hold'),  ('In Progress','Resolved'),
('On Hold','In Progress'),  ('On Hold','Cancelled'),
('Resolved','Closed'),      ('Resolved','Open');

-- ============================================================================
-- TRIGGERS
-- @event_time : optional session clock used when back-loading sample data;
--               the application leaves it NULL so NOW() is used.
-- @app_user_id: optional session variable naming the user making a change.
-- ============================================================================
DELIMITER //

-- T1. New request must start Open; asset (if given) must sit in the same room
CREATE TRIGGER trg_req_bi BEFORE INSERT ON Maintenance_Request
FOR EACH ROW
BEGIN
    DECLARE asset_room INT;
    IF NEW.Status <> 'Open' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: a new request must start in Open status.';
    END IF;
    IF NEW.AssetID IS NOT NULL THEN
        SELECT RoomID INTO asset_room FROM Asset WHERE AssetID = NEW.AssetID;
        IF asset_room <> NEW.RoomID THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Integrity Violation: the asset is not located in the selected room.';
        END IF;
    END IF;
END //

-- T2. Log the initial status
CREATE TRIGGER trg_req_ai AFTER INSERT ON Maintenance_Request
FOR EACH ROW
BEGIN
    INSERT INTO Status_History (RequestID, OldStatus, NewStatus, ChangedAt, ChangedBy)
    VALUES (NEW.RequestID, NULL, NEW.Status, COALESCE(@event_time, NOW()), @app_user_id);
END //

-- T3. Valid status transitions + closure details + work preconditions
CREATE TRIGGER trg_req_bu BEFORE UPDATE ON Maintenance_Request
FOR EACH ROW
BEGIN
    DECLARE ok_move INT;
    DECLARE active_asg INT;
    DECLARE log_cnt INT;

    IF NEW.Status <> OLD.Status THEN
        SELECT COUNT(*) INTO ok_move FROM Status_Transition
        WHERE FromStatus = OLD.Status AND ToStatus = NEW.Status;
        IF ok_move = 0 THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid Status Transition: this move is not allowed by Status_Transition.';
        END IF;

        IF NEW.Status = 'In Progress' THEN
            SELECT COUNT(*) INTO active_asg FROM Assignment
            WHERE RequestID = NEW.RequestID AND Status = 'Active';
            IF active_asg = 0 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Assignment Control: work cannot start without an active technician assignment.';
            END IF;
        END IF;

        IF NEW.Status = 'Resolved' THEN
            SELECT COUNT(*) INTO log_cnt FROM Work_Log wl
            JOIN Assignment a ON wl.AssignmentID = a.AssignmentID
            WHERE a.RequestID = NEW.RequestID;
            IF log_cnt = 0 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Integrity Violation: at least one work log is required before resolving.';
            END IF;
        END IF;

        IF NEW.Status = 'Closed' THEN
            IF NEW.ClosureRemarks IS NULL OR CHAR_LENGTH(TRIM(NEW.ClosureRemarks)) = 0 THEN
                SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Closure Details Required: ClosureRemarks must be provided to close a request.';
            END IF;
            IF NEW.ClosedAt IS NULL THEN
                SET NEW.ClosedAt = COALESCE(@event_time, NOW());
            END IF;
        END IF;
    END IF;
END //

-- T4. Status history is written automatically
CREATE TRIGGER trg_req_au AFTER UPDATE ON Maintenance_Request
FOR EACH ROW
BEGIN
    IF NEW.Status <> OLD.Status THEN
        INSERT INTO Status_History (RequestID, OldStatus, NewStatus, ChangedAt, ChangedBy)
        VALUES (NEW.RequestID, OLD.Status, NEW.Status, COALESCE(@event_time, NOW()), @app_user_id);
    END IF;
END //

-- T5. Assignment control: active technician, load limit, one active job per request
CREATE TRIGGER trg_asg_bi BEFORE INSERT ON Assignment
FOR EACH ROW
BEGIN
    DECLARE tech_active INT;
    DECLARE tech_max INT;
    DECLARE tech_load INT;
    DECLARE req_active INT;
    DECLARE req_status VARCHAR(20);
    DECLARE req_created DATETIME;

    SELECT IsActive, MaxActiveJobs INTO tech_active, tech_max
    FROM Technician WHERE TechID = NEW.TechID;
    IF tech_active = 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assignment Control: technician is inactive (on leave).';
    END IF;

    SELECT COUNT(*) INTO tech_load FROM Assignment
    WHERE TechID = NEW.TechID AND Status = 'Active';
    IF tech_load >= tech_max THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assignment Control: technician has reached the maximum number of active jobs.';
    END IF;

    SELECT COUNT(*) INTO req_active FROM Assignment
    WHERE RequestID = NEW.RequestID AND Status = 'Active';
    IF req_active > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assignment Control: request already has an active assignment (reassign the old one first).';
    END IF;

    SELECT Status, CreatedAt INTO req_status, req_created
    FROM Maintenance_Request WHERE RequestID = NEW.RequestID;
    IF req_status NOT IN ('Open','Assigned','In Progress','On Hold') THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Assignment Control: closed, resolved or cancelled requests cannot be assigned.';
    END IF;
    IF NEW.AssignedAt < req_created THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: assignment cannot be earlier than request creation.';
    END IF;
END //

-- T6. Assigning a technician to an Open request moves it to Assigned
CREATE TRIGGER trg_asg_ai AFTER INSERT ON Assignment
FOR EACH ROW
BEGIN
    UPDATE Maintenance_Request SET Status = 'Assigned'
    WHERE RequestID = NEW.RequestID AND Status = 'Open';
END //

-- T7. Materials: friendly out-of-stock message, then deduct stock
CREATE TRIGGER trg_usage_bi BEFORE INSERT ON Material_Usage
FOR EACH ROW
BEGIN
    DECLARE avail INT;
    SELECT StockQty INTO avail FROM Material WHERE MaterialID = NEW.MaterialID;
    IF avail < NEW.Quantity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock Violation: requested material quantity exceeds available stock.';
    END IF;
END //

CREATE TRIGGER trg_usage_ai AFTER INSERT ON Material_Usage
FOR EACH ROW
BEGIN
    UPDATE Material SET StockQty = StockQty - NEW.Quantity WHERE MaterialID = NEW.MaterialID;
END //

-- T8. Feedback only on closed requests
CREATE TRIGGER trg_feedback_bi BEFORE INSERT ON Feedback
FOR EACH ROW
BEGIN
    DECLARE req_status VARCHAR(20);
    SELECT Status INTO req_status FROM Maintenance_Request WHERE RequestID = NEW.RequestID;
    IF req_status <> 'Closed' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Integrity Violation: feedback is accepted only for Closed requests.';
    END IF;
END //

DELIMITER ;
