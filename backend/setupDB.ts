import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config();

async function setupDatabase() {
    console.log('Connecting to database...');
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASS,
        database: process.env.DB_NAME,
        multipleStatements: true
    });

    const schema = `
        CREATE TABLE IF NOT EXISTS usuarios (
            id INT AUTO_INCREMENT PRIMARY KEY,
            nombre VARCHAR(255) NOT NULL,
            email VARCHAR(255) NOT NULL UNIQUE,
            password VARCHAR(255) NOT NULL,
            whatsapp VARCHAR(50) NULL,
            verificado BOOLEAN DEFAULT FALSE,
            codigo_verificacion VARCHAR(10) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS eventos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            titulo VARCHAR(255) NOT NULL,
            fecha DATE NOT NULL,
            hora TIME,
            categoria VARCHAR(50),
            descripcion TEXT,
            ubicacion VARCHAR(255) DEFAULT '',
            repeticion VARCHAR(50) DEFAULT 'unica',
            costo DECIMAL(10,2) DEFAULT 0.00,
            tipo_transaccion VARCHAR(20) DEFAULT 'ninguno',
            estado_pago VARCHAR(20) DEFAULT 'pendiente',
            uuid_confirmacion VARCHAR(36) UNIQUE,
            parent_id INT NULL,
            frecuencia VARCHAR(50) DEFAULT 'unica',
            tarjeta_credito_id INT NULL,
            transaccion_id INT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
            FOREIGN KEY (parent_id) REFERENCES eventos(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS ciclos_menstruales (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            fecha_inicio DATE NOT NULL,
            observacion TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS notas (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            fecha DATE NOT NULL,
            contenido TEXT NOT NULL,
            etiqueta VARCHAR(30) DEFAULT 'personal',
            color VARCHAR(7) DEFAULT '#4FC3F7',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS habitos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            nombre VARCHAR(100) NOT NULL,
            icono VARCHAR(50) DEFAULT 'check_circle',
            color VARCHAR(7) DEFAULT '#4CAF50',
            frecuencia VARCHAR(20) DEFAULT 'diario',
            meta_diaria INT DEFAULT 1,
            activo BOOLEAN DEFAULT true,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS habitos_log (
            id INT AUTO_INCREMENT PRIMARY KEY,
            habito_id INT NOT NULL,
            user_id INT NOT NULL,
            fecha DATE NOT NULL,
            cantidad INT DEFAULT 1,
            completado BOOLEAN DEFAULT true,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (habito_id) REFERENCES habitos(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
            UNIQUE KEY unique_habito_fecha (habito_id, fecha)
        );

        CREATE TABLE IF NOT EXISTS cumpleanos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            nombre VARCHAR(255) NOT NULL,
            fecha DATE NOT NULL,
            anio_nacimiento INT NULL,
            mensaje TEXT NULL,
            telefono VARCHAR(50) NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS finanzas_cuentas (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            nombre VARCHAR(255) NOT NULL,
            tipo VARCHAR(50) NOT NULL,
            saldo DECIMAL(12,2) DEFAULT 0.00,
            limite DECIMAL(12,2) DEFAULT 0.00,
            interes_tasa DECIMAL(5,2) DEFAULT 0.00,
            fecha_inicio DATE NULL,
            plazo_dias INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS finanzas_ingresos_planificados (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            cuenta_id INT NULL,
            descripcion VARCHAR(255) NOT NULL,
            monto DECIMAL(12,2) NOT NULL,
            frecuencia VARCHAR(50) NOT NULL,
            fecha_inicio DATE NOT NULL,
            activo BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
            FOREIGN KEY (cuenta_id) REFERENCES finanzas_cuentas(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS finanzas_transacciones (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            cuenta_id INT NULL,
            tipo VARCHAR(20) NOT NULL,
            monto DECIMAL(12,2) NOT NULL,
            descripcion VARCHAR(255) NOT NULL,
            fecha DATE NOT NULL,
            categoria VARCHAR(50) DEFAULT 'otros',
            ingreso_planificado_id INT NULL,
            cuotas INT DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
            FOREIGN KEY (cuenta_id) REFERENCES finanzas_cuentas(id) ON DELETE SET NULL,
            FOREIGN KEY (ingreso_planificado_id) REFERENCES finanzas_ingresos_planificados(id) ON DELETE SET NULL
        );

        CREATE TABLE IF NOT EXISTS finanzas_ingresos_verificados (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            ingreso_planificado_id INT NOT NULL,
            fecha_esperada DATE NOT NULL,
            fecha_real DATE NOT NULL,
            monto_real DECIMAL(12,2) NOT NULL,
            transaccion_id INT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
            FOREIGN KEY (ingreso_planificado_id) REFERENCES finanzas_ingresos_planificados(id) ON DELETE CASCADE,
            FOREIGN KEY (transaccion_id) REFERENCES finanzas_transacciones(id) ON DELETE SET NULL,
            UNIQUE KEY unique_verificacion (ingreso_planificado_id, fecha_esperada)
        );

        CREATE TABLE IF NOT EXISTS finanzas_metas (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            nombre VARCHAR(255) NOT NULL,
            descripcion TEXT NULL,
            monto_objetivo DECIMAL(12,2) NOT NULL,
            monto_actual DECIMAL(12,2) DEFAULT 0.00,
            fecha_objetivo DATE NULL,
            icono VARCHAR(50) DEFAULT 'savings',
            color VARCHAR(7) DEFAULT '#34E47E',
            completada BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE
        );

        CREATE TABLE IF NOT EXISTS finanzas_presupuestos (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            categoria VARCHAR(50) NOT NULL,
            monto_limite DECIMAL(12,2) NOT NULL,
            mes INT NOT NULL,
            anio INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
            UNIQUE KEY unique_presupuesto (user_id, categoria, mes, anio)
        );
    `;

    console.log('Executing schema...');
    try {
        await connection.query(schema);
        console.log('Database schema created successfully!');
    } catch (err) {
        console.error('Error creating database schema:', err);
    } finally {
        await connection.end();
    }
}

setupDatabase();
