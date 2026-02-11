USE `ride_match_db`;

-- DML --

-- create accounts
INSERT INTO `account` (UserName, Email, PhoneNum, Password, FirstName, LastName)
VALUES
(null, 'michael-meves@uiowa.edu', null, '1234', 'Michael', 'Meves'),
(null, 'ella-potter@uiowa.edu', null, '1234', 'Ella', 'Potter'),
(null, 'andre-mcgee@uiowa.edu', null, '1234', 'Andre', 'McGee');

-- create admins
INSERT INTO `admin` (AccountID, Role)
VALUES
(1, 'developer'),
(2, 'developer'),
(3, 'developer');

-- create riders
INSERT INTO `rider` (AccountID, Preferences)
VALUES
(1, null),
(2, null),
(3, null);

-- create drivers
INSERT INTO `driver` (AccountID, Preferences)
VALUES
(1, null),
(2, null),
(3, null);

