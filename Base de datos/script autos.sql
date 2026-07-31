-- ==========================================
-- 1. CREACIÓN DE LA TABLA PRINCIPAL
-- ==========================================
-- Esta tabla guardará las coordenadas de los vehículos en la nube.
CREATE TABLE car_locations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) NOT NULL, -- Vinculado al usuario logueado
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  image_url TEXT, -- Aquí guardaremos el enlace de la foto del Storage
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- ==========================================
-- 2. SEGURIDAD (ROW LEVEL SECURITY - RLS)
-- ==========================================
-- Habilitamos la seguridad para evitar que un usuario vea el coche de otro.
ALTER TABLE car_locations ENABLE ROW LEVEL SECURITY;

-- Política: Un usuario solo puede VER sus propios registros
CREATE POLICY "Ver ubicaciones propias" 
  ON car_locations FOR SELECT 
  USING (auth.uid() = user_id);

-- Política: Un usuario solo puede GUARDAR registros a su nombre
CREATE POLICY "Insertar ubicaciones propias" 
  ON car_locations FOR INSERT 
  WITH CHECK (auth.uid() = user_id);

-- Política: Un usuario solo puede ACTUALIZAR sus propios registros
CREATE POLICY "Actualizar ubicaciones propias" 
  ON car_locations FOR UPDATE 
  USING (auth.uid() = user_id);

-- Política: Un usuario solo puede BORRAR sus propios registros
CREATE POLICY "Borrar ubicaciones propias" 
  ON car_locations FOR DELETE 
  USING (auth.uid() = user_id);

-- ==========================================
-- 3. CONFIGURACIÓN DEL STORAGE (FOTOS)
-- ==========================================
-- Creamos el "Bucket" (Caja fuerte) llamado 'car_images' para las fotos del coche.
-- Lo hacemos público (true) para que FlutterMap pueda leer la imagen al mostrarla.
INSERT INTO storage.buckets (id, name, public) 
VALUES ('car_images', 'car_images', true);

-- Habilitamos la seguridad para los archivos
-- Política: Solo los usuarios que iniciaron sesión pueden SUBIR fotos
CREATE POLICY "Usuarios autenticados pueden subir fotos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'car_images');

-- Política: La app puede LEER las fotos para mostrarlas en el mapa
CREATE POLICY "Cualquiera puede leer las fotos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'car_images');
  
-- Política: Solo el dueño puede BORRAR su foto
CREATE POLICY "Usuarios pueden borrar sus fotos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'car_images');