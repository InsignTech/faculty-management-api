const express = require('express');
const router = express.Router();

// Middlewares: parse raw text since ADMS devices send data in custom text formats
router.use(express.text({ type: '*/*', limit: '10mb' }));

const handleAdmsRequest = (req, res) => {
    console.log('====== ADMS / eSSL Device Request Received ======');
    console.log('Time:', new Date().toISOString());
    console.log('HTTP Method:', req.method);
    console.log('Original URL:', req.originalUrl);
    console.log('Query Parameters:', req.query);
    console.log('Headers:', req.headers);
    console.log('Body Length:', req.body ? req.body.length : 0);
    if (req.body) {
        console.log('Body Preview (first 1000 chars):');
        console.log(req.body.substring(0, 1000));
    }
    console.log('================================================');

    // Respond back to the device to acknowledge receipt
    res.status(200).send('OK');
};

// Define explicit routes used by eSSL / ZKTeco ADMS devices (with and without .aspx extension)
router.all('/cdata', handleAdmsRequest);
router.all('/cdata.aspx', handleAdmsRequest);

router.all('/getrequest', handleAdmsRequest);
router.all('/getrequest.aspx', handleAdmsRequest);

router.all('/registry', handleAdmsRequest);
router.all('/registry.aspx', handleAdmsRequest);

router.all('/devicecmd', handleAdmsRequest);
router.all('/devicecmd.aspx', handleAdmsRequest);

router.all('/', handleAdmsRequest);

module.exports = router;
