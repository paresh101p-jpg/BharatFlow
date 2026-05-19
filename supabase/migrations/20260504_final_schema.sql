-- 1. CLEANUP (पुरानी टेबल्स को पूरी तरह हटाना)
DROP TABLE IF EXISTS mandi_prices CASCADE;
DROP TABLE IF EXISTS market_news CASCADE;
DROP TABLE IF EXISTS transport_bookings CASCADE;
DROP TABLE IF EXISTS khata_transactions CASCADE;
DROP TABLE IF EXISTS store_products CASCADE;
DROP TABLE IF EXISTS mandi_events CASCADE;
DROP TABLE IF EXISTS soil_health_records CASCADE;

-- 2. MANDI INTELLIGENCE (मंडी भाव और स्टॉक)
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
    opening_hours TEXT DEFAULT '04:00 AM - 08:00 PM',
    contact_no TEXT
);

-- 3. MARKET NEWS (न्यूज़ और अपडेट्स)
CREATE TABLE market_news (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    category TEXT,
    image_url TEXT,
    impact_level TEXT DEFAULT 'Medium',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. LOGISTICS (ट्रांसपोर्ट बुकिंग)
CREATE TABLE transport_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transporter_name TEXT,
    vehicle_type TEXT,
    origin TEXT,
    destination TEXT,
    fare NUMERIC,
    status TEXT DEFAULT 'Confirmed',
    tracking_id TEXT,
    estimated_delivery TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. DIGITAL KHATA (बहीखाता)
CREATE TABLE khata_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    type TEXT NOT NULL, -- Credit / Debit
    category TEXT,
    payment_method TEXT DEFAULT 'Cash',
    transaction_date DATE DEFAULT CURRENT_DATE
);

-- 6. BHARAT BRAND STORE (प्रोडक्ट्स)
CREATE TABLE store_products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT,
    price NUMERIC NOT NULL,
    original_price NUMERIC,
    discount_pct NUMERIC,
    image_url TEXT,
    is_govt_certified BOOLEAN DEFAULT TRUE
);

-- 7. MANDI CALENDAR (त्यौहार और छुट्टियां)
CREATE TABLE mandi_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    event_date DATE NOT NULL,
    event_type TEXT,
    is_closed BOOLEAN DEFAULT TRUE,
    description TEXT
);

-- 8. SOIL HEALTH (मिट्टी की जांच)
CREATE TABLE soil_health_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_location TEXT,
    nitrogen_level TEXT,
    ph_value NUMERIC,
    recommendation TEXT,
    report_date DATE DEFAULT CURRENT_DATE
);

-- 9. SAMPLE DATA (रियल डेटा का अहसास कराने के लिए)
INSERT INTO mandi_prices (commodity_name, variety, mandi_name, mandi_code, min_price, max_price, modal_price, sentiment, stock_status, state)
VALUES 
('Wheat', 'Sharbati', 'Azadpur', 'DL-APMC-01', 2300, 2600, 2450, 'Bullish', 'Full Stock', 'Delhi'),
('Tomato', 'Hybrid', 'Azadpur', 'DL-APMC-01', 1200, 2000, 1800, 'Bearish', 'Low Stock', 'Delhi'),
('Onion', 'Nasik Red', 'Sahibabad', 'UP-GZ-42', 3000, 3500, 3200, 'Bullish', 'Full Stock', 'UP');

INSERT INTO market_news (title, category, impact_level)
VALUES 
('New MSP for Wheat announced: ₹2275/q', 'Policy', 'High'),
('Weather Alert: Heavy rain expected in Punjab', 'Weather', 'Medium');

INSERT INTO store_products (name, category, price, original_price, discount_pct)
VALUES 
('Bharat Urea Premium', 'Fertilizer', 266, 300, 12),
('High Yield Rice Seeds', 'Seeds', 1100, 1400, 21);

INSERT INTO mandi_events (title, event_date, event_type)
VALUES 
('Diwali Celebration', '2024-11-01', 'Festival'),
('State Holiday', '2024-11-10', 'Govt Holiday');
