-- ============================================================================
-- PROJECT 41 - REPORT / DEMO QUERIES (run after seed.py)
-- Each query is the same SQL pattern the application uses for its reports.
-- ============================================================================
USE CampusMaintenanceDB;

-- 1. PENDING REQUESTS (view + join) with SLA breach flag
SELECT RequestNo, Title, Priority, Building, RoomNo, AgeHours, SLAHours,
       CASE WHEN AgeHours > SLAHours THEN 'OVERDUE' ELSE 'OK' END AS SLAStatus
FROM vw_PendingRequests
ORDER BY PriorityRank, CreatedAt;

-- 2. AGEING of pending requests (nested query in FROM, aggregate)
SELECT bucket, COUNT(*) AS Requests FROM (
    SELECT CASE WHEN AgeHours < 24  THEN '0-1 day'
                WHEN AgeHours < 72  THEN '1-3 days'
                WHEN AgeHours < 168 THEN '3-7 days' ELSE '7+ days' END AS bucket
    FROM vw_PendingRequests) x
GROUP BY bucket;

-- 3. RESPONSE TIME per priority (derived table join, aggregates)
SELECT p.Name AS Priority, p.SLAHours, COUNT(*) AS Requests,
       ROUND(AVG(TIMESTAMPDIFF(MINUTE, r.CreatedAt, fa.FirstAssigned))/60, 2) AS AvgResponseHrs
FROM Request r
JOIN Priority p ON r.PriorityID = p.PriorityID
JOIN (SELECT RequestID, MIN(AssignedAt) AS FirstAssigned FROM Assignment GROUP BY RequestID) fa
     ON fa.RequestID = r.RequestID
GROUP BY p.PriorityID, p.Name, p.SLAHours, p.Rank_
ORDER BY p.Rank_;

-- 4. TECHNICIAN LOAD (left joins, conditional aggregation)
SELECT t.Name, c.Name AS Trade, t.MaxOpenJobs,
       COALESCE(SUM(a.IsActive = 1 AND r.Status IN ('ASSIGNED','IN_PROGRESS','ON_HOLD')), 0) AS OpenJobs,
       COUNT(a.AssignmentID) AS TotalJobs
FROM Technician t
JOIN Category c ON t.CategoryID = c.CategoryID
LEFT JOIN Assignment a ON a.TechnicianID = t.TechnicianID
LEFT JOIN Request r ON r.RequestID = a.RequestID
GROUP BY t.TechnicianID, t.Name, c.Name, t.MaxOpenJobs
ORDER BY OpenJobs DESC;

-- 5. BUILDING-WISE COST (view + multi-table join + SUM)
SELECT b.Name AS Building, COUNT(r.RequestID) AS Requests,
       SUM(vc.LabourCost) AS Labour, SUM(vc.MaterialCost) AS Materials,
       SUM(vc.LabourCost + vc.MaterialCost) AS Total
FROM Building b
JOIN Room rm ON rm.BuildingID = b.BuildingID
JOIN Request r ON r.RoomID = rm.RoomID
JOIN vw_RequestCost vc ON vc.RequestID = r.RequestID
GROUP BY b.BuildingID, b.Name
ORDER BY Total DESC;

-- 6. MATERIAL USE (aggregate, HAVING)
SELECT m.Name, SUM(mu.Quantity) AS QtyUsed, SUM(mu.Quantity * mu.UnitCostAtUse) AS Cost
FROM Material m JOIN MaterialUsage mu ON mu.MaterialID = m.MaterialID
GROUP BY m.MaterialID, m.Name
HAVING SUM(mu.Quantity) > 0
ORDER BY Cost DESC;

-- 7. FEEDBACK per technician (join + AVG)
SELECT t.Name, COUNT(f.FeedbackID) AS Responses, ROUND(AVG(f.Rating), 2) AS AvgRating
FROM Technician t
JOIN Assignment a ON a.TechnicianID = t.TechnicianID
JOIN Feedback f ON f.RequestID = a.RequestID
GROUP BY t.TechnicianID, t.Name
ORDER BY AvgRating DESC;

-- 8. SUBQUERY: requests whose cost is above the average request cost
SELECT r.RequestNo, r.Title, vc.LabourCost + vc.MaterialCost AS Cost
FROM Request r JOIN vw_RequestCost vc ON vc.RequestID = r.RequestID
WHERE vc.LabourCost + vc.MaterialCost >
      (SELECT AVG(LabourCost + MaterialCost) FROM vw_RequestCost WHERE LabourCost + MaterialCost > 0)
ORDER BY Cost DESC;

-- 9. SUBQUERY: technicians who have never been assigned a Critical request
SELECT Name FROM Technician t
WHERE NOT EXISTS (SELECT 1 FROM Assignment a JOIN Request r ON r.RequestID = a.RequestID
                  JOIN Priority p ON p.PriorityID = r.PriorityID
                  WHERE a.TechnicianID = t.TechnicianID AND p.Name = 'Critical');

-- ----------------------------------------------------------------------------
-- RULE DEMONSTRATIONS (each statement below SHOULD FAIL - show the error live)
-- ----------------------------------------------------------------------------
-- a) invalid status transition (OPEN -> RESOLVED)
-- UPDATE Request SET Status='RESOLVED' WHERE Status='OPEN' LIMIT 1;
-- b) closing without remarks
-- UPDATE Request SET Status='CLOSED', ClosedAt=NOW() WHERE Status='RESOLVED' LIMIT 1;
-- c) negative material cost
-- INSERT INTO Material (Name, Unit, UnitCost, StockQty) VALUES ('Bad', 'pcs', -1, 5);
-- d) duplicate request number
-- INSERT INTO Request (RequestNo,Title,RequestedBy,RoomID,CategoryID,PriorityID)
--   SELECT RequestNo,'dup',RequestedBy,RoomID,CategoryID,PriorityID FROM Request LIMIT 1;
-- e) assigning an inactive technician
-- INSERT INTO Assignment (RequestID, TechnicianID)
--   SELECT (SELECT RequestID FROM Request WHERE Status='OPEN' LIMIT 1),
--          (SELECT TechnicianID FROM Technician WHERE IsActive=0 LIMIT 1);

-- ----------------------------------------------------------------------------
-- TRANSACTION AWARENESS (what the app does for "assign")
-- ----------------------------------------------------------------------------
-- START TRANSACTION;
--   SELECT Status FROM Request WHERE RequestID = 1 FOR UPDATE;
--   INSERT INTO Assignment (RequestID, TechnicianID) VALUES (1, 1);
--   UPDATE Request SET Status = 'ASSIGNED' WHERE RequestID = 1;
-- COMMIT;   -- or ROLLBACK; if any step raised an error
