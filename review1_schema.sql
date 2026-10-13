CREATE DATABASE IF NOT EXISTS CampusMaintenance;
USE CampusMaintenance;

CREATE TABLE Building (
    BuildingID INT PRIMARY KEY,
    Name VARCHAR(80) NOT NULL
);

CREATE TABLE Room (
    RoomID INT PRIMARY KEY,
    BuildingID INT,
    RoomNo VARCHAR(30) NOT NULL,
    FOREIGN KEY (BuildingID) REFERENCES Building(BuildingID)
);

CREATE TABLE Asset (
    AssetID INT PRIMARY KEY,
    RoomID INT,
    Name VARCHAR(80) NOT NULL,
    FOREIGN KEY (RoomID) REFERENCES Room(RoomID)
);

CREATE TABLE AppUser (
    UserID INT PRIMARY KEY,
    Name VARCHAR(80) NOT NULL,
    Email VARCHAR(120),
    Role VARCHAR(10)
);

CREATE TABLE Category (
    CategoryID INT PRIMARY KEY,
    Name VARCHAR(50) NOT NULL
);

CREATE TABLE Priority (
    PriorityID INT PRIMARY KEY,
    Name VARCHAR(20) NOT NULL,
    SlaHours INT
);

CREATE TABLE Technician (
    TechID INT PRIMARY KEY,
    Name VARCHAR(80) NOT NULL,
    Phone VARCHAR(15),
    CategoryID INT,
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID)
);

CREATE TABLE Material (
    MaterialID INT PRIMARY KEY,
    Name VARCHAR(80) NOT NULL,
    UnitCost DECIMAL(10,2)
);

CREATE TABLE Request (
    RequestID INT PRIMARY KEY,
    RequestNo VARCHAR(12) NOT NULL,
    UserID INT,
    RoomID INT,
    AssetID INT,
    CategoryID INT,
    PriorityID INT,
    Description VARCHAR(500),
    Status VARCHAR(12),
    CreatedAt DATETIME,
    ClosedAt DATETIME,
    ClosureRemarks VARCHAR(300),
    FOREIGN KEY (UserID) REFERENCES AppUser(UserID),
    FOREIGN KEY (RoomID) REFERENCES Room(RoomID),
    FOREIGN KEY (AssetID) REFERENCES Asset(AssetID),
    FOREIGN KEY (CategoryID) REFERENCES Category(CategoryID),
    FOREIGN KEY (PriorityID) REFERENCES Priority(PriorityID)
);

CREATE TABLE Assignment (
    AssignID INT PRIMARY KEY,
    RequestID INT,
    TechID INT,
    AssignedAt DATETIME,
    FOREIGN KEY (RequestID) REFERENCES Request(RequestID),
    FOREIGN KEY (TechID) REFERENCES Technician(TechID)
);

CREATE TABLE WorkLog (
    LogID INT PRIMARY KEY,
    AssignID INT,
    Note VARCHAR(300),
    Hours DECIMAL(5,2),
    LoggedAt DATETIME,
    FOREIGN KEY (AssignID) REFERENCES Assignment(AssignID)
);

CREATE TABLE MaterialUse (
    UseID INT PRIMARY KEY,
    LogID INT,
    MaterialID INT,
    Qty INT,
    FOREIGN KEY (LogID) REFERENCES WorkLog(LogID),
    FOREIGN KEY (MaterialID) REFERENCES Material(MaterialID)
);

CREATE TABLE StatusHistory (
    HistID INT PRIMARY KEY,
    RequestID INT,
    OldStatus VARCHAR(12),
    NewStatus VARCHAR(12),
    ChangedAt DATETIME,
    FOREIGN KEY (RequestID) REFERENCES Request(RequestID)
);

CREATE TABLE Feedback (
    RequestID INT PRIMARY KEY,
    Rating TINYINT,
    Comments VARCHAR(300),
    FOREIGN KEY (RequestID) REFERENCES Request(RequestID)
);
