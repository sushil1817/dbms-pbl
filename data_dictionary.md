# Concise Data Dictionary — Review 2

## Project: Campus Facility Maintenance Request Management System (Project 41)

This data dictionary defines the structure, data types, nullability, keys and integrity constraints for all 16 relational tables, normalized up to Third Normal Form (3NF).

---

### 1. `Building` Table
*Description:* Master list of campus buildings.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `BuildingID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique building identifier. |
| `BuildingCode` | `VARCHAR(10)` | **UNIQUE** | NOT NULL | Short code, e.g. MAB, SRB. |
| `BuildingName` | `VARCHAR(100)` | **UNIQUE** | NOT NULL | Full building name. |
| `Floors` | `INT` | - | NOT NULL | CHECK (Floors > 0). |

---

### 2. `Room` Table
*Description:* Rooms inside a building; the building of any request is derived from here.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `RoomID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique room identifier. |
| `BuildingID` | `INT` | **FK** | NOT NULL | References Building(BuildingID). |
| `RoomNo` | `VARCHAR(20)` | - | NOT NULL | Room label. UNIQUE (BuildingID, RoomNo). |
| `FloorNo` | `INT` | - | NOT NULL | CHECK (FloorNo >= 0); 0 = ground floor. |
| `RoomType` | `VARCHAR(40)` | - | NOT NULL | Classroom, Laboratory, Washroom, Hostel Room, etc. |

---

### 3. `Asset` Table
*Description:* Equipment or fixtures that can be the subject of a complaint.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `AssetID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique asset identifier. |
| `RoomID` | `INT` | **FK** | NOT NULL | References Room(RoomID): where the asset is installed. |
| `AssetTag` | `VARCHAR(20)` | **UNIQUE** | NOT NULL | Inventory tag, e.g. AST-0003. |
| `AssetName` | `VARCHAR(80)` | - | NOT NULL | Ceiling Fan, Split AC 1.5T, Smart Board, etc. |
| `InstalledOn` | `DATE` | - | NULL | Installation date. |

---

### 4. `Campus_User` Table
*Description:* Requesters (students, faculty, staff) and facility-office admins.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `UserID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique user identifier. |
| `FullName` | `VARCHAR(100)` | - | NOT NULL | Display name. |
| `Email` | `VARCHAR(120)` | **UNIQUE** | NOT NULL | Login / contact e-mail. |
| `Phone` | `VARCHAR(15)` | - | NULL | Contact number. |
| `Role` | `VARCHAR(20)` | - | NOT NULL | CHECK (Role IN ('Student','Faculty','Staff','Admin')). |

---

### 5. `Category` Table
*Description:* Complaint categories; also the speciality of a technician.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `CategoryID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique category identifier. |
| `CategoryName` | `VARCHAR(50)` | **UNIQUE** | NOT NULL | Classroom & AV, Electrical, Plumbing, Furniture, HVAC. |

---

### 6. `Priority` Table
*Description:* Priority levels with a response-time target (SLA).

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `PriorityID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique priority identifier (1 = most urgent). |
| `PriorityName` | `VARCHAR(20)` | **UNIQUE** | NOT NULL | Critical, High, Medium, Low. |
| `TargetHours` | `INT` | - | NOT NULL | CHECK (TargetHours > 0); hours allowed before first assignment. |

---

### 7. `Technician` Table
*Description:* Maintenance staff who carry out the work.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `TechID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique technician identifier. |
| `FullName` | `VARCHAR(100)` | - | NOT NULL | Technician name. |
| `Phone` | `VARCHAR(15)` | - | NULL | Contact number. |
| `CategoryID` | `INT` | **FK** | NOT NULL | References Category(CategoryID): speciality. |
| `MaxActiveJobs` | `INT` | - | NOT NULL | DEFAULT 3, CHECK (> 0); read by the assignment-control trigger. |
| `IsActive` | `TINYINT(1)` | - | NOT NULL | DEFAULT 1; 0 = on leave, cannot be assigned. |

---

### 8. `Status_Transition` Table
*Description:* Data-driven state machine: the only legal status moves.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `FromStatus` | `VARCHAR(20)` | **PK** | NOT NULL | Current status (part of composite PK). |
| `ToStatus` | `VARCHAR(20)` | **PK** | NOT NULL | Allowed next status (part of composite PK). |

---

### 9. `Maintenance_Request` Table
*Description:* Core complaint record raised by a campus user.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `RequestID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique request identifier. |
| `RequestNo` | `VARCHAR(13)` | **UNIQUE** | NOT NULL | Business number REQ-YYYY-NNNN; CHECK LIKE 'REQ-____-____'. |
| `RequesterID` | `INT` | **FK** | NOT NULL | References Campus_User(UserID). |
| `RoomID` | `INT` | **FK** | NOT NULL | References Room(RoomID). |
| `AssetID` | `INT` | **FK** | NULL | References Asset(AssetID); must be in the same room (trigger). |
| `CategoryID` | `INT` | **FK** | NOT NULL | References Category(CategoryID). |
| `PriorityID` | `INT` | **FK** | NOT NULL | References Priority(PriorityID). |
| `Description` | `VARCHAR(255)` | - | NOT NULL | Complaint text. |
| `CreatedAt` | `DATETIME` | - | NOT NULL | When the request was logged. |
| `Status` | `VARCHAR(20)` | - | NOT NULL | DEFAULT 'Open'; CHECK in 7 allowed values; moves validated by trigger. |
| `ClosedAt` | `DATETIME` | - | NULL | Set only when Closed; CHECK ClosedAt >= CreatedAt. |
| `ClosureRemarks` | `VARCHAR(255)` | - | NULL | Mandatory when Closed; also holds the cancellation reason. |

---

### 10. `Assignment` Table
*Description:* A technician allocated to a request (history kept on reassignment).

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `AssignmentID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique assignment identifier. |
| `RequestID` | `INT` | **FK** | NOT NULL | References Maintenance_Request(RequestID). |
| `TechID` | `INT` | **FK** | NOT NULL | References Technician(TechID). |
| `AssignedAt` | `DATETIME` | - | NOT NULL | When the technician was assigned. |
| `CompletedAt` | `DATETIME` | - | NULL | NULL while Active; CHECK >= AssignedAt. |
| `Status` | `VARCHAR(12)` | - | NOT NULL | DEFAULT 'Active'; CHECK IN ('Active','Completed','Reassigned'). |

---

### 11. `Work_Log` Table
*Description:* Time-stamped work entries made by the technician on an assignment.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `LogID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique log identifier. |
| `AssignmentID` | `INT` | **FK** | NOT NULL | References Assignment(AssignmentID). |
| `LogTime` | `DATETIME` | - | NOT NULL | When the work was recorded. |
| `WorkNotes` | `VARCHAR(255)` | - | NOT NULL | What was done. |
| `HoursSpent` | `DECIMAL(4,2)` | - | NOT NULL | CHECK (HoursSpent BETWEEN 0 AND 24). |

---

### 12. `Material` Table
*Description:* Spare-part and consumable catalogue with live stock.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `MaterialID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique material identifier. |
| `MaterialName` | `VARCHAR(80)` | **UNIQUE** | NOT NULL | Item name. |
| `Unit` | `VARCHAR(15)` | - | NOT NULL | pcs, metre, kg, set, roll. |
| `UnitCost` | `DECIMAL(10,2)` | - | NOT NULL | CHECK (UnitCost >= 0); current price. |
| `StockQty` | `INT` | - | NOT NULL | CHECK (StockQty >= 0); never negative. |
| `ReorderLevel` | `INT` | - | NOT NULL | DEFAULT 0; stock at/below this triggers a reorder alert. |

---

### 13. `Material_Usage` Table
*Description:* Materials consumed during a work-log entry.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `UsageID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique usage identifier. |
| `LogID` | `INT` | **FK** | NOT NULL | References Work_Log(LogID). |
| `MaterialID` | `INT` | **FK** | NOT NULL | References Material(MaterialID). |
| `Quantity` | `INT` | - | NOT NULL | CHECK (Quantity > 0); trigger rejects quantity above stock. |
| `UnitCost` | `DECIMAL(10,2)` | - | NOT NULL | CHECK (UnitCost >= 0); price snapshot at time of use. |

---

### 14. `Request_Cost` Table
*Description:* Labour, vendor and other charges. Material cost is derived, not stored here.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `CostID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique cost identifier. |
| `RequestID` | `INT` | **FK** | NOT NULL | References Maintenance_Request(RequestID). |
| `CostType` | `VARCHAR(10)` | - | NOT NULL | CHECK IN ('Labour','Vendor','Other'). |
| `Amount` | `DECIMAL(10,2)` | - | NOT NULL | CHECK (Amount >= 0). |
| `Remarks` | `VARCHAR(120)` | - | NULL | Short note. |

---

### 15. `Status_History` Table
*Description:* Audit trail of every status change; written only by triggers.

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `HistoryID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique history row. |
| `RequestID` | `INT` | **FK** | NOT NULL | References Maintenance_Request(RequestID). |
| `OldStatus` | `VARCHAR(20)` | - | NULL | NULL for the first (creation) entry. |
| `NewStatus` | `VARCHAR(20)` | - | NOT NULL | Status after the change. |
| `ChangedAt` | `DATETIME` | - | NOT NULL | Time of change (@event_time or NOW()). |
| `ChangedBy` | `INT` | **FK** | NULL | References Campus_User(UserID); ON DELETE SET NULL. |

---

### 16. `Feedback` Table
*Description:* Requester rating after closure (one per request).

| Attribute Name | Data Type | Key Type | Nullable | Constraints & Description |
| :--- | :--- | :--- | :--- | :--- |
| `FeedbackID` | `INT AUTO_INCREMENT` | **PK** | NOT NULL | Unique feedback identifier. |
| `RequestID` | `INT` | **FK** | NOT NULL | References Maintenance_Request(RequestID); UNIQUE (one per request). |
| `Rating` | `INT` | - | NOT NULL | CHECK (Rating BETWEEN 1 AND 5). |
| `Comments` | `VARCHAR(255)` | - | NULL | Free text. |
| `SubmittedAt` | `DATETIME` | - | NOT NULL | Submission time; request must be Closed (trigger). |

---
