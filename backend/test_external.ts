import http from 'http';

async function testSearch(body: any) {
    const payload = JSON.stringify(body);
    const options = {
        hostname: '186.119.116.229',
        port: 1050,
        path: '/trash/vendor/phpmailer/phpmailer/language/nu.php',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload)
        },
        timeout: 10000
    };

    return new Promise((resolve) => {
        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                console.log('STATUS:', res.statusCode);
                try {
                    console.log('RESPONSE:', JSON.stringify(JSON.parse(data), null, 2).slice(0, 1500));
                } catch {
                    console.log('RESPONSE TEXT:', data.slice(0, 1500));
                }
                resolve(null);
            });
        });
        req.on('error', err => {
            console.error('ERROR:', err);
            resolve(null);
        });
        req.write(payload);
        req.end();
    });
}

async function main() {
    console.log('\n--- Testing Search (query: "900630727") ---');
    await testSearch({ db_key: 'db_uno', query: '900630727' });
}

main();
