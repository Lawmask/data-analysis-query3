USE data_analysis3


-- =========================================
-- CREATE DATABASE
-- =========================================
CREATE DATABASE IF NOT EXISTS OnlineStore;
USE OnlineStore;

-- =========================================
-- CUSTOMERS TABLE
-- =========================================
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY AUTO_INCREMENT,
    FirstName VARCHAR(50) NOT NULL,
    LastName VARCHAR(50) NOT NULL,
    Email VARCHAR(100) UNIQUE NOT NULL,
    Phone VARCHAR(15),
    
    CONSTRAINT chk_phone
    CHECK (Phone REGEXP '^[0-9]{10,15}$')
);

-- =========================================
-- PRODUCTS TABLE
-- =========================================
CREATE TABLE Products (
    ProductID INT PRIMARY KEY AUTO_INCREMENT,
    ProductName VARCHAR(100) NOT NULL,
    Price DECIMAL(10,2),
    StockQuantity INT,

    CONSTRAINT chk_price
    CHECK (Price > 0),

    CONSTRAINT chk_stock
    CHECK (StockQuantity >= 0)
);


-- =========================================
-- ORDERS TABLE WITH RANGE PARTITIONING
-- =========================================
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY AUTO_INCREMENT,
    CustomerID INT,
    OrderDate DATE NOT NULL,
    TotalAmount DECIMAL(10,2),

    CONSTRAINT fk_customer
    FOREIGN KEY (CustomerID)
    REFERENCES Customers(CustomerID),

    CONSTRAINT chk_total
    CHECK (TotalAmount > 0)
)

PARTITION BY RANGE (YEAR(OrderDate)) (
    PARTITION p_before_2023 VALUES LESS THAN (2023),
    PARTITION p_2023_and_after VALUES LESS THAN MAXVALUE
);

-- =========================================
-- ORDER DETAILS TABLE
-- =========================================
CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY AUTO_INCREMENT,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    Subtotal DECIMAL(10,2),

    CONSTRAINT fk_order
    FOREIGN KEY (OrderID)
    REFERENCES Orders(OrderID)
    ON DELETE CASCADE,

    CONSTRAINT fk_product
    FOREIGN KEY (ProductID)
    REFERENCES Products(ProductID),

    CONSTRAINT chk_quantity
    CHECK (Quantity > 0),

    CONSTRAINT chk_subtotal
    CHECK (Subtotal > 0)
);

-- =========================================
-- INSERT SAMPLE DATA
-- =========================================
INSERT INTO Customers (FirstName, LastName, Email, Phone)
VALUES
('John', 'Doe', 'john@gmail.com', '08012345678'),
('Mary', 'Smith', 'mary@gmail.com', '08123456789');

INSERT INTO Products (ProductName, Price, StockQuantity)
VALUES
('Laptop', 250000.00, 10),
('Phone', 120000.00, 5),
('Headset', 15000.00, 20);

-- =========================================
-- TRANSACTION FOR ORDER PURCHASE
-- =========================================

START TRANSACTION;

-- Variables
SET @ProductID = 2;
SET @CustomerID = 1;
SET @Quantity = 2;

-- Check Stock
SELECT StockQuantity
INTO @CurrentStock
FROM Products
WHERE ProductID = @ProductID;

-- If stock is enough
SET @Price = (
    SELECT Price
    FROM Products
    WHERE ProductID = @ProductID
);

SET @Subtotal = @Price * @Quantity;

-- CONDITION CHECK
-- If stock available
IF @CurrentStock >= @Quantity THEN

    -- Insert into Orders table
    INSERT INTO Orders (CustomerID, OrderDate, TotalAmount)
    VALUES (@CustomerID, CURDATE(), @Subtotal);

    -- Get last inserted OrderID
    SET @OrderID = LAST_INSERT_ID();

    -- Insert into OrderDetails
    INSERT INTO OrderDetails (OrderID, ProductID, Quantity, Subtotal)
    VALUES (@OrderID, @ProductID, @Quantity, @Subtotal);

    -- Reduce stock
    UPDATE Products
    SET StockQuantity = StockQuantity - @Quantity
    WHERE ProductID = @ProductID;

    COMMIT;

ELSE

    -- Rollback if stock not available
    ROLLBACK;

END IF;