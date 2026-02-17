USE `ride_match_db`;

-- DML --

-- clear existing data before reseeding
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE `driver_review`;
TRUNCATE TABLE `trip`;
TRUNCATE TABLE `rider_saves`;
TRUNCATE TABLE `car`;
TRUNCATE TABLE `driver_information`;
TRUNCATE TABLE `payment`;
TRUNCATE TABLE `admin_action`;
TRUNCATE TABLE `driver`;
TRUNCATE TABLE `rider`;
TRUNCATE TABLE `admin`;
TRUNCATE TABLE `account`;
SET FOREIGN_KEY_CHECKS = 1;

-- create accounts
INSERT INTO `account` (UserName, Email, PhoneNum, Password, FirstName, LastName)
VALUES
('michaelm', 'michael-meves@uiowa.edu', '319-555-0101', '1234', 'Michael', 'Meves'),
('ellap', 'ella-potter@uiowa.edu', '319-555-0102', '1234', 'Ella', 'Potter'),
('andrem', 'andre-mcgee@uiowa.edu', '319-555-0103', '1234', 'Andre', 'McGee'),
('sofiar', 'sofia.ramirez@example.com', '319-555-0104', '1234', 'Sofia', 'Ramirez'),
('liamc', 'liam.carter@example.com', '319-555-0105', '1234', 'Liam', 'Carter'),
('noahb', 'noah.bennett@example.com', '319-555-0106', '1234', 'Noah', 'Bennett'),
('avat', 'ava.thompson@example.com', '319-555-0107', '1234', 'Ava', 'Thompson'),
('masonl', 'mason.lee@example.com', '319-555-0108', '1234', 'Mason', 'Lee'),
('chloew', 'chloe.walker@example.com', '319-555-0109', '1234', 'Chloe', 'Walker'),
('ethanb', 'ethan.brooks@example.com', '319-555-0110', '1234', 'Ethan', 'Brooks'),
('miaf', 'mia.foster@example.com', '319-555-0111', '1234', 'Mia', 'Foster'),
('loganp', 'logan.price@example.com', '319-555-0112', '1234', 'Logan', 'Price'),
('harperr', 'harper.reed@example.com', '319-555-0113', '1234', 'Harper', 'Reed'),
('owenh', 'owen.hayes@example.com', '319-555-0114', '1234', 'Owen', 'Hayes'),
('gracek', 'grace.kelly@example.com', '319-555-0115', '1234', 'Grace', 'Kelly'),
('lucasm', 'lucas.miller@example.com', '319-555-0116', '1234', 'Lucas', 'Miller'),
('emmad', 'emma.davis@example.com', '319-555-0117', '1234', 'Emma', 'Davis'),
('calebj', 'caleb.jordan@example.com', '319-555-0118', '1234', 'Caleb', 'Jordan');

-- create admins
INSERT INTO `admin` (AccountID, Role)
VALUES
(1, 'developer'),
(2, 'developer'),
(3, 'developer');

-- create riders (allow broad rider activity in analytics/reviews)
INSERT INTO `rider` (AccountID, Preferences)
VALUES
(1, 'quiet ride'),
(2, 'music okay'),
(3, 'no highway'),
(4, 'quiet ride'),
(5, 'music okay'),
(6, 'pet friendly'),
(7, 'quiet ride'),
(8, 'music okay'),
(9, 'quiet ride'),
(10, 'pet friendly'),
(11, 'music okay'),
(12, 'quiet ride'),
(13, 'quiet ride'),
(14, 'music okay'),
(15, 'pet friendly'),
(16, 'quiet ride'),
(17, 'music okay'),
(18, 'quiet ride');

-- create drivers
INSERT INTO `driver` (AccountID, Preferences)
VALUES
(1, 'quiet rider'),
(2, 'music low'),
(3, 'conversation okay'),
(7, 'quiet rider'),
(8, 'music low'),
(9, 'pet friendly'),
(10, 'conversation okay'),
(11, 'quiet rider'),
(12, 'music low'),
(13, 'quiet rider'),
(14, 'conversation okay'),
(15, 'quiet rider');

-- set driver statuses for admin workflows
UPDATE `driver`
SET `Status` = 'approved'
WHERE `AccountID` IN (1, 2, 8, 9, 11, 12);

UPDATE `driver`
SET `Status` = 'pending'
WHERE `AccountID` IN (3, 7, 10, 13);

UPDATE `driver`
SET `Status` = 'under_review'
WHERE `AccountID` = 14;

UPDATE `driver`
SET `Status` = 'denied'
WHERE `AccountID` = 15;

-- create driver information records
INSERT INTO `driver_information`
(`DriverID`, `FirstName`, `LastName`, `Email`, `PhoneNum`, `DateOfBirth`, `LicenseState`, `LicenseNumber`, `LicenseExpires`, `InsuranceProvider`, `InsurancePolicy`, `InformationNotes`)
VALUES
(1, 'Michael', 'Meves', 'michael-meves@uiowa.edu', '319-555-0101', '1989-03-10', 'IA', 'IA-100001', '2028-07-15', 'State Farm', 'SF-2001', 'High reliability and strong rider feedback.'),
(2, 'Ella', 'Potter', 'ella-potter@uiowa.edu', '319-555-0102', '1994-06-22', 'IA', 'IA-100002', '2027-05-31', 'GEICO', 'GE-2002', 'Approved with no issues.'),
(3, 'Andre', 'McGee', 'andre-mcgee@uiowa.edu', '319-555-0103', '2000-11-03', 'IA', 'IA-100003', '2026-09-20', 'Progressive', 'PR-2003', 'Waiting on final background verification.'),
(7, 'Ava', 'Thompson', 'ava.thompson@example.com', '319-555-0107', '1997-02-14', 'IL', 'IL-100007', '2026-08-01', 'Allstate', 'AL-2007', 'Pending interview scheduling.'),
(8, 'Mason', 'Lee', 'mason.lee@example.com', '319-555-0108', '1991-09-09', 'IA', 'IA-100008', '2029-01-11', 'State Farm', 'SF-2008', 'Strong safety score.'),
(9, 'Chloe', 'Walker', 'chloe.walker@example.com', '319-555-0109', '1988-04-25', 'MN', 'MN-100009', '2027-12-19', 'Progressive', 'PR-2009', 'Experienced long-distance driver.'),
(10, 'Ethan', 'Brooks', 'ethan.brooks@example.com', '319-555-0110', '1999-01-30', 'IA', 'IA-100010', '2026-03-28', 'Farmers', 'FA-2010', 'Pending new insurance card upload.'),
(11, 'Mia', 'Foster', 'mia.foster@example.com', '319-555-0111', '1993-05-05', 'WI', 'WI-100011', '2028-10-30', 'GEICO', 'GE-2011', 'Approved after document audit.'),
(12, 'Logan', 'Price', 'logan.price@example.com', '319-555-0112', '1992-12-12', 'IA', 'IA-100012', '2027-04-16', 'State Farm', 'SF-2012', 'High completion rate.'),
(13, 'Harper', 'Reed', 'harper.reed@example.com', '319-555-0113', '1998-07-19', 'NE', 'NE-100013', '2026-11-02', 'Allstate', 'AL-2013', 'Pending final license check.'),
(14, 'Owen', 'Hayes', 'owen.hayes@example.com', '319-555-0114', '1995-08-08', 'IA', 'IA-100014', '2027-06-23', 'Progressive', 'PR-2014', 'Under review after rider complaint.'),
(15, 'Grace', 'Kelly', 'grace.kelly@example.com', '319-555-0115', '2001-10-02', 'IA', 'IA-100015', '2025-12-01', 'Unknown', 'UN-2015', 'Denied due to expired documents.');

-- create car records
INSERT INTO `car` (`DriverID`, `PlateNum`, `Make`, `Model`, `Color`)
VALUES
(1, 'RM-101A', 'Toyota', 'Camry', 'Black'),
(2, 'RM-102B', 'Honda', 'Accord', 'White'),
(3, 'RM-103C', 'Hyundai', 'Elantra', 'Gray'),
(7, 'RM-107D', 'Nissan', 'Altima', 'Blue'),
(8, 'RM-108E', 'Kia', 'Sportage', 'Silver'),
(9, 'RM-109F', 'Subaru', 'Forester', 'Green'),
(10, 'RM-110G', 'Ford', 'Escape', 'Black'),
(11, 'RM-111H', 'Chevrolet', 'Malibu', 'White'),
(12, 'RM-112J', 'Toyota', 'RAV4', 'Red'),
(13, 'RM-113K', 'Honda', 'CR-V', 'Blue'),
(14, 'RM-114L', 'Mazda', 'CX-5', 'Gray'),
(15, 'RM-115M', 'Volkswagen', 'Jetta', 'White');

-- create trips
INSERT INTO `trip` (`RiderID`, `DriverID`, `Status`, `StartLoc`, `EndLoc`, `FinalCost`, `DriverRate`, `RiderRate`)
VALUES
(2, 1, 'completed', 'Iowa City', 'Coralville', 12.50, 5, 5),
(3, 1, 'completed', 'North Liberty', 'Iowa City', 15.25, 5, 4),
(4, 2, 'completed', 'Coralville', 'North Liberty', 18.10, 4, 5),
(5, 7, 'completed', 'Iowa City', 'Cedar Rapids', 24.30, 4, 4),
(6, 8, 'completed', 'Coralville', 'Iowa City', 10.75, 5, 5),
(16, 9, 'completed', 'Iowa City', 'Solon', 16.80, 5, 5),
(17, 10, 'completed', 'Coralville', 'Tiffin', 14.20, 4, 4),
(18, 11, 'completed', 'North Liberty', 'Coralville', 11.60, 5, 5),
(1, 12, 'completed', 'Iowa City', 'North Liberty', 13.95, 5, 5),
(2, 13, 'completed', 'Coralville', 'Iowa City', 9.40, 3, 4),
(3, 14, 'completed', 'Iowa City', 'Coralville', 12.10, 3, 3),
(4, 15, 'completed', 'Iowa City', 'Cedar Rapids', 28.00, 2, 2),
(5, 7, 'canceled', 'Coralville', 'Iowa City', 0.00, NULL, NULL),
(6, 10, 'completed', 'Iowa City', 'North Liberty', 14.90, 4, 4),
(16, 2, 'completed', 'Tiffin', 'Iowa City', 19.75, 5, 5),
(17, 8, 'completed', 'Iowa City', 'Coralville', 11.45, 5, 5),
(18, 9, 'completed', 'Solon', 'Iowa City', 18.25, 5, 5),
(1, 11, 'in_progress', 'Coralville', 'North Liberty', 0.00, NULL, NULL),
(2, 12, 'requested', 'Iowa City', 'Coralville', 0.00, NULL, NULL),
(3, 1, 'completed', 'Iowa City', 'Tiffin', 17.35, 5, 5);

-- create rider reviews for drivers
INSERT INTO `driver_review` (`DriverID`, `RiderID`, `TripID`, `Rating`, `Comment`)
VALUES
(1, 2, 1, 5, 'Great communication and smooth driving.'),
(1, 3, 2, 4, 'On-time pickup and friendly.'),
(2, 4, 3, 5, 'Driver was punctual and professional.'),
(7, 5, 4, 4, 'Clean car and safe driving style.'),
(8, 6, 5, 5, 'Excellent overall experience.'),
(9, 16, 6, 5, 'Very efficient route and friendly service.'),
(10, 17, 7, 4, 'Solid ride, slight delay at pickup.'),
(11, 18, 8, 5, 'Outstanding service and clean vehicle.'),
(12, 1, 9, 5, 'Quick and smooth trip.'),
(13, 2, 10, 3, 'Driver was okay but route was longer than expected.'),
(14, 3, 11, 2, 'Unsafe lane changes made me uncomfortable.'),
(15, 4, 12, 1, 'Documentation concerns and poor experience.'),
(2, 16, 15, 5, 'Very professional and helpful with luggage.'),
(8, 17, 16, 5, 'Friendly and careful driver.'),
(9, 18, 17, 5, 'Great ride and clear communication.'),
(1, 3, 20, 5, 'Consistently reliable and courteous.');
