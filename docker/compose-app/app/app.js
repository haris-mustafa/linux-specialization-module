const express = require('express');
const mongoose = require('mongoose');

const app = express();
const PORT = 3000;

// Connect to MongoDB
// "mongodb" is the container name — Docker resolves it automatically
mongoose.connect('mongodb://mongodb:27017/visitordb', {
    useNewUrlParser: true,
    useUnifiedTopology: true
});

// Simple counter schema
const CounterSchema = new mongoose.Schema({
    count: { type: Number, default: 0 }
});

const Counter = mongoose.model('Counter', CounterSchema);

// Main route — increment and show count
app.get('/', async (req, res) => {
    try {
        // Find or create counter
        let counter = await Counter.findOne();
        if (!counter) {
            counter = new Counter({ count: 0 });
        }

        // Increment
        counter.count++;
        await counter.save();

        res.send(`
            <!DOCTYPE html>
            <html>
            <head>
                <title>DevOps Visitor Counter</title>
                <style>
                    body {
                        background: #1a1a2e;
                        color: #00ff88;
                        font-family: Arial;
                        text-align: center;
                        padding: 50px;
                    }
                    h1 { font-size: 48px; }
                    .count {
                        font-size: 100px;
                        font-weight: bold;
                        color: #ffffff;
                    }
                    p { color: #aaa; }
                </style>
            </head>
            <body>
                <h1>Visitor Counter</h1>
                <div class="count">${counter.count}</div>
                <p>Powered by: Node.js + MongoDB + nginx + Docker Compose</p>
                <p>Refresh to increment!</p>
            </body>
            </html>
        `);
    } catch (err) {
        res.status(500).send('Database error: ' + err.message);
    }
});

// Health check endpoint — used by monitoring
app.get('/health', (req, res) => {
    res.json({ status: 'ok', uptime: process.uptime() });
});

app.listen(PORT, () => {
    console.log(`App running on port ${PORT}`);
});
