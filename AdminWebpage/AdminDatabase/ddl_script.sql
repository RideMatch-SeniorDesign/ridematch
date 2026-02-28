-- DDL --
DROP DATABASE IF EXISTS `ride_match_db`;
CREATE DATABASE `ride_match_db`;
USE `ride_match_db`;

-- ACCOUNT TABLE
CREATE TABLE `account` (
	`AccountID` int AUTO_INCREMENT,
    `UserName` varchar(50),
    `Email` varchar(100) NOT NULL,
    `PhoneNum` varchar(20),
    `Password` varchar(100) NOT NULL,
    `FirstName` varchar(50) NOT NULL,
    `LastName` varchar(50) NOT NULL,
    PRIMARY KEY (`AccountID`),
    UNIQUE KEY `Email_UQ` (`Email`)
);

-- ADMIN TABLE
CREATE TABLE `admin` (
	`AccountID` int NOT NULL,
    `Role` varchar(20),
    PRIMARY KEY (`AccountID`),
    CONSTRAINT `Admin_AccountID` FOREIGN KEY (`AccountID`) REFERENCES `account` (`AccountID`)
);

-- ADMIN_ACTION RELATIONAL TABLE
CREATE TABLE `admin_action` (
	`ActionID` int AUTO_INCREMENT,
	`AdminID` int NOT NULL,
    `TargetID` int NOT NULL,
    `Action` varchar(20) NOT NULL,
    `Reason` varchar(100),
    `ActDate` timestamp(6) DEFAULT current_timestamp(6),
    PRIMARY KEY (`ActionID`, `AdminID`, `TargetID`),
    CONSTRAINT `FK_AdminID_act` FOREIGN KEY (`AdminID`) REFERENCES `admin` (`AccountID`),
    CONSTRAINT `FK_TargetID_act` FOREIGN KEY (`TargetID`) REFERENCES `account` (`AccountID`)
);

-- RIDER TABLE
CREATE TABLE `rider` (
	`AccountID` int NOT NULL,
    `Preferences` varchar(100),
    `Rating` int DEFAULT 5,
    `Status` varchar(50),
    PRIMARY KEY (`AccountID`),
    CONSTRAINT `Rider_AccountID` FOREIGN KEY (`AccountID`) REFERENCES `account` (`AccountID`)
);

-- PAYMENT TABLE
CREATE TABLE `payment` (
	`PaymentID` int AUTO_INCREMENT,
    `RiderID` int NOT NULL,
    `PaymentType` varchar(50) NOT NULL,
    -- TODO: add other necessary payment info
    PRIMARY KEY (`PaymentID`),
    CONSTRAINT `FK_RiderID_payment` FOREIGN KEY (`RiderID`) REFERENCES `rider` (`AccountID`)
);

-- DRIVER TABLE
CREATE TABLE `driver` (
	`AccountID` int NOT NULL,
    `Preferences` varchar(100),
    `Rating` int DEFAULT 5,
    `Status` varchar(50) DEFAULT 'pending',
    `SubmittedAt` timestamp(6) NOT NULL DEFAULT current_timestamp(6),
    `ApprovedAt` timestamp(6) DEFAULT NULL,
    PRIMARY KEY (`AccountID`),
    CONSTRAINT `Driver_AccountID` FOREIGN KEY (`AccountID`) REFERENCES `account` (`AccountID`)
);

-- DRIVER_INFORMATION TABLE
CREATE TABLE `driver_information` (
    `DriverID` int NOT NULL,
    `FirstName` varchar(50) DEFAULT NULL,
    `LastName` varchar(50) DEFAULT NULL,
    `Email` varchar(100) DEFAULT NULL,
    `PhoneNum` varchar(20) DEFAULT NULL,
    `DateOfBirth` date DEFAULT NULL,
    `LicenseState` varchar(2) DEFAULT NULL,
    `LicenseNumber` varchar(50) DEFAULT NULL,
    `LicenseExpires` date DEFAULT NULL,
    `InsuranceProvider` varchar(100) DEFAULT NULL,
    `InsurancePolicy` varchar(50) DEFAULT NULL,
    `InformationNotes` varchar(255) DEFAULT NULL,
    `UpdatedAt` timestamp(6) DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
    PRIMARY KEY (`DriverID`),
    UNIQUE KEY `DriverInfoEmail_UQ` (`Email`),
    UNIQUE KEY `LicenseNumber_UQ` (`LicenseNumber`),
    CONSTRAINT `FK_DriverID_driver_information` FOREIGN KEY (`DriverID`) REFERENCES `driver` (`AccountID`)
);

-- CAR TABLE
CREATE TABLE `car` (
    `DriverID` int NOT NULL,
    `PlateNum` varchar(50) NOT NULL,
    `Make` varchar(50) NOT NULL,
    `Model` varchar(50) NOT NULL,
    `Color` varchar(50) NOT NULL,
    PRIMARY KEY (`DriverID`, `PlateNum`),
    UNIQUE KEY `PlateNum_UQ` (`PlateNum`)
);

-- RIDER_SAVES RELATIONAL TABLE
CREATE TABLE `rider_saves` (
	`RiderID` int NOT NULL,
    `DriverID` int NOT NULL,
    `Approved` boolean DEFAULT false,
    PRIMARY KEY (`RiderID`, `DriverID`),
    CONSTRAINT `FK_RiderID_saves` FOREIGN KEY (`RiderID`) REFERENCES `rider` (`AccountID`),
    CONSTRAINT `FK_DriverID_saves` FOREIGN KEY (`DriverID`) REFERENCES `driver` (`AccountID`)
);

-- TRIP RELATIONAL TABLE
CREATE TABLE `trip` (
	`TripID` int AUTO_INCREMENT,
    `RiderID` int NOT NULL,
    `DriverID` int NOT NULL,
    `Status` enum('requested', 'accepted', 'in_progress', 'canceled', 'completed') NOT NULL,
    `StartLoc` varchar(100) NOT NULL,
    `EndLoc` varchar(100) NOT NULL,
    `FinalCost` decimal(10,2) DEFAULT 0.00,
    `DriverRate` int,
    `RiderRate` int,
    PRIMARY KEY (`TripID`),
    CONSTRAINT `FK_RiderID_trip` FOREIGN KEY (`RiderID`) REFERENCES `rider` (`AccountID`),
    CONSTRAINT `FK_DriverID_trip` FOREIGN KEY (`DriverID`) REFERENCES `driver` (`AccountID`)
);

-- DRIVER_REVIEW TABLE
CREATE TABLE `driver_review` (
    `ReviewID` int AUTO_INCREMENT,
    `DriverID` int NOT NULL,
    `RiderID` int NOT NULL,
    `TripID` int,
    `Rating` int NOT NULL,
    `Comment` varchar(255),
    `ReviewDate` timestamp(6) DEFAULT current_timestamp(6),
    PRIMARY KEY (`ReviewID`),
    CONSTRAINT `FK_DriverID_driver_review` FOREIGN KEY (`DriverID`) REFERENCES `driver` (`AccountID`),
    CONSTRAINT `FK_RiderID_driver_review` FOREIGN KEY (`RiderID`) REFERENCES `rider` (`AccountID`),
    CONSTRAINT `FK_TripID_driver_review` FOREIGN KEY (`TripID`) REFERENCES `trip` (`TripID`)
);

-- Triggers --

-- Views --

-- ADMIN_LOGIN VIEW
CREATE VIEW `admin_login` AS
SELECT
	A.UserName,
    A.Email,
    A.Password,
    A.PhoneNum,
    A.FirstName,
    A.LastName
FROM `account` A
JOIN `admin` Ad ON Ad.AccountID = A.AccountID;

-- RIDER_LOGIN VIEW
CREATE VIEW `rider_login` AS
SELECT
	A.UserName,
    A.Email,
    A.Password,
    A.PhoneNum,
    A.FirstName,
    A.LastName,
    R.Status
FROM `account` A
JOIN `rider` R ON R.AccountID = A.AccountID;

-- DRIVER_LOGIN VIEW
CREATE VIEW `driver_login` AS
SELECT
	A.UserName,
    A.Email,
    A.Password,
    A.PhoneNum,
    A.FirstName,
    A.LastName,
    D.Status
FROM `account` A
JOIN `driver` D ON D.AccountID = A.AccountID;
