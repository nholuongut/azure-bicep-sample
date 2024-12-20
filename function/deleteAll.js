const mysql = require('mysql');
const fs = require('fs');

//https://docs.microsoft.com/en-us/azure/key-vault/secrets/quick-create-node
const { SecretClient } = require("@azure/keyvault-secrets");
const { DefaultAzureCredential } = require("@azure/identity");
dotenv.config();

const credential = new DefaultAzureCredential();

const keyVaultName = process.env["KEY_VAULT_NAME"];
const url = "https://" + keyVaultName + ".vault.azure.net";

const client = new SecretClient(url, credential);
const username = await client.getSecret(username);
const password = await client.getSecret(password);

var config =
{
    host: 'mydemoserver.mysql.database.azure.com',
    user: username,
    password: password,
    database: 'quickstartdb',
    port: 3306,
    ssl: {ca: fs.readFileSync("BaltimoreCyberTrustRoot.crt.pem")}
};

const conn = new mysql.createConnection(config);

conn.connect(
    function (err) { 
        if (err) { 
            console.log("!!! Cannot connect !!! Error:");
            throw err;
        }
        else {
            console.log("Connection established.");
            deleteData();
        }
    });

function deleteData(){
       conn.query('DELETE FROM inventory', [], 
            function (err, results, fields) {
                if (err) throw err;
                else console.log('Deleted ' + results.affectedRows + ' row(s).');
           })
       conn.end(
           function (err) { 
                if (err) throw err;
                else  console.log('Done.') 
        });
};