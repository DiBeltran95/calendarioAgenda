import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config();

async function run() {
    const connection = await mysql.createConnection({
        host: process.env.DB_HOST,
        user: process.env.DB_USER,
        password: process.env.DB_PASS,
        database: process.env.DB_NAME
    });

    try {
        const [result]: any = await connection.execute(
            'UPDATE usuarios SET password = ? WHERE email = ?',
            ['dfa2c3a8e96d13c008fc60fbfccc50596dae1a69e0aa8659ec2399d4d3c5ee00', 'di.beltran@udla.edu.co']
        );
        console.log('Password restored successfully:', result.affectedRows);
    } catch (err) {
        console.error(err);
    } finally {
        await connection.end();
    }
}

run();
