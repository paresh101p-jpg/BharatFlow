-- 1. CLEANUP
DROP TABLE IF EXISTS mandi_prices CASCADE;
DROP TABLE IF EXISTS market_news CASCADE;
DROP TABLE IF EXISTS transport_bookings CASCADE;
DROP TABLE IF EXISTS khata_transactions CASCADE;
DROP TABLE IF EXISTS store_products CASCADE;
DROP TABLE IF EXISTS mandi_events CASCADE;
DROP TABLE IF EXISTS soil_health_records CASCADE;

-- 2. MANDI INTELLIGENCE
CREATE TABLE mandi_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commodity_name TEXT NOT NULL,
    variety TEXT,
    mandi_name TEXT NOT NULL,
    mandi_code TEXT,
    state TEXT,
    district TEXT,
    min_price NUMERIC,
    max_price NUMERIC,
    modal_price NUMERIC,
    arrival_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    arrival_quantity NUMERIC,
    unit TEXT DEFAULT 'Quintal',
    sentiment TEXT DEFAULT 'Neutral',
    stock_status TEXT DEFAULT 'Full Stock',
    distance_km NUMERIC,
    opening_hours TEXT DEFAULT '09:00 AM - 06:00 PM',
    contact_no TEXT DEFAULT '+91 98765 43210',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. MARKET NEWS
CREATE TABLE market_news (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    category TEXT, -- Policy, Price Alert, Weather, Arrival
    impact_level TEXT, -- High, Medium, Low
    published_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. TRANSPORT BOOKINGS
CREATE TABLE transport_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transporter_name TEXT,
    vehicle_type TEXT,
    origin TEXT,
    destination TEXT,
    fare NUMERIC,
    status TEXT DEFAULT 'Pending', -- Pending, In Transit, Delivered
    tracking_id TEXT,
    booking_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    estimated_delivery TIMESTAMP WITH TIME ZONE
);

-- 5. KHATA TRANSACTIONS
CREATE TABLE khata_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    type TEXT NOT NULL, -- Credit, Debit
    category TEXT,
    payment_method TEXT DEFAULT 'Cash',
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    notes TEXT
);

-- 6. BHARAT BRAND STORE
CREATE TABLE store_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT,
    price NUMERIC NOT NULL,
    original_price NUMERIC,
    discount_pct NUMERIC,
    image_url TEXT,
    is_govt_certified BOOLEAN DEFAULT TRUE,
    stock_quantity INTEGER DEFAULT 100
);

-- 7. MANDI EVENTS
CREATE TABLE mandi_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_name TEXT NOT NULL,
    mandi_name TEXT,
    event_date DATE,
    event_type TEXT, -- Holiday, Maintenance, Election, Festival
    impact_level TEXT -- Closed, Partial, Open
);

-- 8. SOIL HEALTH RECORDS
CREATE TABLE soil_health_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    field_name TEXT NOT NULL,
    nitrogen NUMERIC,
    phosphorus NUMERIC,
    potassium NUMERIC,
    ph_level NUMERIC,
    moisture_pct NUMERIC,
    overall_score INTEGER,
    recommendations TEXT,
    last_sampled TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ==========================================
-- SAMPLE DATA (50+ Mandi Price Records)
-- ==========================================

INSERT INTO mandi_prices (commodity_name, variety, mandi_name, state, district, min_price, max_price, modal_price, distance_km, sentiment, stock_status)
VALUES 
('Onion', 'Red', 'Lasalgaon', 'Maharashtra', 'Nashik', 1200, 2450, 1800, 245, 'Bullish', 'Limited Stock'),
('Onion', 'White', 'Pimpalgaon', 'Maharashtra', 'Nashik', 1100, 2200, 1650, 260, 'Neutral', 'Full Stock'),
('Onion', 'Red', 'Surat', 'Gujarat', 'Surat', 1300, 2600, 1950, 12, 'Bullish', 'Full Stock'),
('Onion', 'Nasik Red', 'Bardoli', 'Gujarat', 'Surat', 1250, 2550, 1900, 34, 'Bullish', 'Full Stock'),
('Wheat', 'Lok-1', 'Surat', 'Gujarat', 'Surat', 2100, 2800, 2450, 12, 'Neutral', 'Full Stock'),
('Wheat', 'Sarbati', 'Indore', 'Madhya Pradesh', 'Indore', 2400, 3200, 2800, 450, 'Neutral', 'Full Stock'),
('Potato', 'Jyoti', 'Agra', 'Uttar Pradesh', 'Agra', 800, 1400, 1100, 800, 'Bearish', 'High Arrival'),
('Potato', 'Desi', 'Bardoli', 'Gujarat', 'Surat', 900, 1500, 1200, 34, 'Neutral', 'Full Stock'),
('Tomato', 'Hybrid', 'Nasik', 'Maharashtra', 'Nashik', 1500, 3500, 2500, 245, 'Bullish', 'Low Stock'),
('Cotton', 'V797', 'Amreli', 'Gujarat', 'Amreli', 7000, 8500, 7800, 300, 'Bullish', 'Full Stock'),
('Cotton', 'Shankar 6', 'Rajkot', 'Gujarat', 'Rajkot', 7200, 8800, 8000, 280, 'Bullish', 'Full Stock'),
('Garlic', 'Desi', 'Mandsaur', 'Madhya Pradesh', 'Mandsaur', 4000, 12000, 8000, 500, 'Bullish', 'Low Stock'),
('Ginger', 'Fresh', 'Bangalore', 'Karnataka', 'Bangalore', 5000, 9000, 7000, 1200, 'Neutral', 'Full Stock'),
('Chili', 'Guntur', 'Guntur', 'Andhra Pradesh', 'Guntur', 15000, 22000, 18500, 950, 'Bullish', 'Full Stock'),
('Lemon', 'Local', 'Ahmednagar', 'Maharashtra', 'Ahmednagar', 3000, 6000, 4500, 350, 'Neutral', 'Full Stock'),
('Apple', 'Royal Delicious', 'Shimla', 'Himachal Pradesh', 'Shimla', 4000, 10000, 7000, 1500, 'Bullish', 'Full Stock'),
('Banana', 'Robusta', 'Jalgaon', 'Maharashtra', 'Jalgaon', 800, 1800, 1300, 400, 'Neutral', 'Full Stock'),
('Soyabean', 'Yellow', 'Ujjain', 'Madhya Pradesh', 'Ujjain', 4500, 5500, 5000, 480, 'Neutral', 'Full Stock'),
('Mustard', 'Pusa', 'Bharatpur', 'Rajasthan', 'Bharatpur', 5000, 6500, 5800, 700, 'Bullish', 'Full Stock'),
('Rice', 'Basmati', 'Karnal', 'Haryana', 'Karnal', 3500, 5500, 4500, 1100, 'Neutral', 'Full Stock'),
('Rice', 'Sona Masuri', 'Raichur', 'Karnataka', 'Raichur', 2800, 3800, 3300, 1300, 'Neutral', 'Full Stock'),
('Onion', 'Red', 'Pune', 'Maharashtra', 'Pune', 1200, 2300, 1750, 320, 'Neutral', 'Full Stock'),
('Onion', 'Garwa', 'Solapur', 'Maharashtra', 'Solapur', 1000, 2100, 1550, 400, 'Neutral', 'Full Stock'),
('Wheat', 'Kalyansona', 'Ludhiana', 'Punjab', 'Ludhiana', 2125, 2300, 2250, 1200, 'Neutral', 'Full Stock'),
('Wheat', 'Desi', 'Ambala', 'Haryana', 'Ambala', 2150, 2400, 2275, 1150, 'Neutral', 'Full Stock'),
('Tomato', 'Local', 'Surat', 'Gujarat', 'Surat', 1200, 2500, 1850, 12, 'Bullish', 'Limited Stock'),
('Tomato', 'Hybrid', 'Bardoli', 'Gujarat', 'Surat', 1400, 2800, 2100, 34, 'Bullish', 'Full Stock'),
('Potato', 'Chipsona', 'Haldwani', 'Uttarakhand', 'Nainital', 1000, 1800, 1400, 950, 'Neutral', 'Full Stock'),
('Potato', 'Red', 'Kolkata', 'West Bengal', 'Howrah', 1200, 2000, 1600, 1800, 'Neutral', 'Full Stock'),
('Cotton', 'BT', 'Aurangabad', 'Maharashtra', 'Aurangabad', 6800, 8200, 7500, 350, 'Neutral', 'Full Stock'),
('Cotton', 'Long Staple', 'Warangal', 'Telangana', 'Warangal', 7500, 9000, 8250, 1100, 'Bullish', 'Full Stock'),
('Ginger', 'Assam', 'Guwahati', 'Assam', 'Kamrup', 4500, 8500, 6500, 2200, 'Neutral', 'Full Stock'),
('Garlic', 'Ooty', 'Ooty', 'Tamil Nadu', 'Nilgiris', 6000, 15000, 10000, 1400, 'Bullish', 'Limited Stock'),
('Chili', 'Teja', 'Khammam', 'Telangana', 'Khammam', 18000, 25000, 21000, 1050, 'Bullish', 'Full Stock'),
('Lemon', 'Seedless', 'Anantapur', 'Andhra Pradesh', 'Anantapur', 4000, 8000, 6000, 1100, 'Neutral', 'Full Stock'),
('Banana', 'Grand Naine', 'Ananthapur', 'Andhra Pradesh', 'Anantapur', 1000, 2000, 1500, 1150, 'Neutral', 'Full Stock'),
('Mango', 'Alphonso', 'Ratnagiri', 'Maharashtra', 'Ratnagiri', 30000, 80000, 50000, 450, 'Bullish', 'Season Peak'),
('Mango', 'Kesar', 'Junagadh', 'Gujarat', 'Junagadh', 15000, 40000, 25000, 350, 'Bullish', 'Season Peak'),
('Rice', 'Kolam', 'Gondia', 'Maharashtra', 'Gondia', 3500, 5000, 4200, 750, 'Neutral', 'Full Stock'),
('Mustard', 'Black', 'Rewari', 'Haryana', 'Rewari', 5200, 6800, 6000, 950, 'Neutral', 'Full Stock'),
('Mustard', 'Yellow', 'Agra', 'Uttar Pradesh', 'Agra', 5500, 7200, 6400, 800, 'Bullish', 'Full Stock'),
('Soyabean', '9560', 'Dewas', 'Madhya Pradesh', 'Dewas', 4600, 5600, 5100, 460, 'Neutral', 'Full Stock'),
('Soyabean', 'JS-335', 'Latur', 'Maharashtra', 'Latur', 4400, 5400, 4900, 550, 'Neutral', 'Full Stock'),
('Onion', 'Red', 'Mehsana', 'Gujarat', 'Mehsana', 1100, 2300, 1700, 280, 'Neutral', 'Full Stock'),
('Wheat', 'Tukda', 'Rajkot', 'Gujarat', 'Rajkot', 2300, 2900, 2600, 280, 'Neutral', 'Full Stock'),
('Tomato', 'Local', 'Navsari', 'Gujarat', 'Navsari', 1100, 2300, 1700, 45, 'Neutral', 'Full Stock'),
('Potato', 'Desi', 'Anand', 'Gujarat', 'Anand', 850, 1450, 1150, 180, 'Neutral', 'Full Stock'),
('Rice', 'IR-64', 'Raipur', 'Chhattisgarh', 'Raipur', 2000, 2600, 2300, 900, 'Neutral', 'Full Stock'),
('Rice', 'Swarna', 'Bhubaneswar', 'Odisha', 'Khurda', 1900, 2500, 2200, 1400, 'Neutral', 'Full Stock'),
('Cotton', 'Desi', 'Sirsa', 'Haryana', 'Sirsa', 6500, 7800, 7200, 1050, 'Neutral', 'Full Stock');

-- Sample News Data
INSERT INTO market_news (title, content, category, impact_level)
VALUES 
('Government increases Onion Export Duty', 'The Indian government has increased the export duty on onions to 40% to ensure domestic availability and control prices.', 'Policy', 'High'),
('Rain in Nashik affects Onion arrivals', 'Unseasonal rainfall in Nashik region has slowed down onion arrivals in major mandis like Lasalgaon.', 'Weather', 'Medium'),
('Wheat procurement targets revised', 'FCI has revised the wheat procurement targets for the upcoming season in Punjab and Haryana.', 'Arrival', 'Medium'),
('New Fertilizer Subsidy announced', 'The government announced a fresh subsidy of ₹24,000 crores for DAP and other complex fertilizers.', 'Policy', 'High'),
('Tomato prices likely to cool down', 'Increased arrivals from southern states expected to bring down tomato prices in northern markets.', 'Price Alert', 'Low');

-- Sample Store Products
INSERT INTO store_products (name, category, price, original_price, discount_pct, image_url, is_govt_certified)
VALUES 
('Bharat Urea', 'Fertilizer', 266, 350, 24, 'https://images.unsplash.com/photo-1586771107445-d3ca888129ff?q=80&w=500&auto=format&fit=crop', TRUE),
('Bharat DAP', 'Fertilizer', 1350, 1600, 15, 'https://images.unsplash.com/photo-1592982537447-6f2a6a0c3000?q=80&w=500&auto=format&fit=crop', TRUE),
('Bharat Seeds - Wheat', 'Seeds', 1200, 1500, 20, 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?q=80&w=500&auto=format&fit=crop', TRUE),
('Bharat Atta', 'Atta', 275, 360, 23, 'https://images.unsplash.com/photo-1509440159596-0249088772ff?q=80&w=500&auto=format&fit=crop', TRUE),
('Bharat Dal (Chana)', 'Dal', 60, 95, 36, 'https://images.unsplash.com/photo-1585994192701-90a60424597b?q=80&w=500&auto=format&fit=crop', TRUE);

-- Sample Transport Bookings
INSERT INTO transport_bookings (transporter_name, vehicle_type, origin, destination, fare, status, tracking_id)
VALUES 
('Bharat Logistics', 'Eicher 14ft', 'Surat Mandi', 'Vapi Warehouse', 4500, 'In Transit', 'TRK9001'),
('Karnal Express', 'Tata Ace', 'Karnal Mandi', 'Delhi Azadpur', 3200, 'Pending', 'TRK9002'),
('Mandi Goods', 'Truck 20ft', 'Bardoli Mandi', 'Ahmedabad', 8500, 'Delivered', 'TRK9003');

-- Sample Khata Transactions
INSERT INTO khata_transactions (title, amount, type, category, payment_method)
VALUES 
('Sold Onion 50Q', 75000, 'Credit', 'Sales', 'UPI'),
('Bought Seeds', 1200, 'Debit', 'Purchase', 'Cash'),
('Transport Fare Paid', 4500, 'Debit', 'Logistics', 'Cash'),
('Sold Wheat 20Q', 48000, 'Credit', 'Sales', 'Bank Transfer');

-- Sample Mandi Events
INSERT INTO mandi_events (event_name, mandi_name, event_date, event_type, impact_level)
VALUES 
('Weekly Holiday', 'Lasalgaon Mandi', '2026-05-10', 'Holiday', 'Closed'),
('Local Election', 'Surat Mandi', '2026-05-15', 'Election', 'Closed'),
('GST Maintenance', 'All Mandis', '2026-05-20', 'Maintenance', 'Partial');

-- Sample Soil Health Records
INSERT INTO soil_health_records (field_name, nitrogen, phosphorus, potassium, ph_level, moisture_pct, overall_score, recommendations)
VALUES 
('North-1 Field', 0.8, 0.4, 0.7, 6.8, 22, 85, 'Apply Phosphorus 5kg/acre, Nitrogen is optimal'),
('South-2 Field', 0.5, 0.6, 0.5, 7.2, 18, 72, 'Increase Nitrogen by 10%, pH is slightly high');
