-- Enable PostGIS extension agar pehle se on nahi hai (Maps ke liye zaroori hai)
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Farms Table
CREATE TABLE IF NOT EXISTS public.mk_farms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    area_acres NUMERIC(10, 4),
    area_bigha NUMERIC(10, 4),
    area_hectare NUMERIC(10, 4),
    boundary GEOMETRY(POLYGON, 4326),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Faster map search ke liye Spatial Index
CREATE INDEX IF NOT EXISTS mk_farms_boundary_idx ON public.mk_farms USING GIST (boundary);

-- 2. Sub Plots Table
CREATE TABLE IF NOT EXISTS public.mk_sub_plots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_id UUID REFERENCES public.mk_farms(id) ON DELETE CASCADE,
    crop_name VARCHAR(100) NOT NULL,
    size_acres NUMERIC(10, 4),
    sowing_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Soil Health Table
CREATE TABLE IF NOT EXISTS public.mk_soil_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_id UUID REFERENCES public.mk_farms(id) ON DELETE CASCADE,
    moisture_index NUMERIC(5, 2),
    status VARCHAR(50), 
    fetched_from VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Weather Cache Table
CREATE TABLE IF NOT EXISTS public.mk_weather_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    location GEOMETRY(POINT, 4326),
    forecast_data JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 15km caching queries ko fast karne ke liye Spatial Index
CREATE INDEX IF NOT EXISTS mk_weather_cache_location_idx ON public.mk_weather_cache USING GIST (location);

-- 5. Farm Diary Table
CREATE TABLE IF NOT EXISTS public.mk_farm_diary (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farm_id UUID REFERENCES public.mk_farms(id) ON DELETE CASCADE,
    entry_type VARCHAR(20) CHECK (entry_type IN ('INCOME', 'EXPENSE')),
    category VARCHAR(50),
    amount NUMERIC(12, 2) NOT NULL,
    description TEXT,
    entry_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE public.mk_farms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mk_sub_plots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mk_soil_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mk_weather_cache ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mk_farm_diary ENABLE ROW LEVEL SECURITY;

-- Policy: Koi bhi user sirf apna khet dekh, daal, ya delete kar sakega
CREATE POLICY "Users can view their own farms" ON public.mk_farms FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own farms" ON public.mk_farms FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own farms" ON public.mk_farms FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete their own farms" ON public.mk_farms FOR DELETE USING (auth.uid() = user_id);
