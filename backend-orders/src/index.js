const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const axios = require('axios');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const PORT = process.env.PORT || 3002;
const DB_HOST = process.env.DB_HOST || 'mysql';
const DB_PORT = process.env.DB_PORT || 3306;
const DB_USER = process.env.DB_USER || 'root';
const DB_PASSWORD = process.env.DB_PASSWORD || 'password';
const DB_NAME = process.env.DB_NAME || 'inovatech';
const PRODUCTS_SERVICE = process.env.PRODUCTS_SERVICE || 'http://products-service:3001';

let pool;

// Inicializar conexión a base de datos
async function initDatabase() {
  try {
    pool = mysql.createPool({
      host: DB_HOST,
      port: DB_PORT,
      user: DB_USER,
      password: DB_PASSWORD,
      database: DB_NAME,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });
    console.log('✓ Database connected');
  } catch (error) {
    console.error('✗ Database connection failed:', error);
    setTimeout(initDatabase, 5000);
  }
}

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'UP', service: 'orders' });
});

// Get all orders
app.get('/api/orders', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    const [orders] = await connection.query('SELECT * FROM orders');
    connection.release();
    res.json(orders);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch orders' });
  }
});

// Get order by ID
app.get('/api/orders/:id', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    const [orders] = await connection.query('SELECT * FROM orders WHERE id = ?', [req.params.id]);
    connection.release();
    if (orders.length === 0) {
      return res.status(404).json({ error: 'Order not found' });
    }
    res.json(orders[0]);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch order' });
  }
});

// Create order with product validation
app.post('/api/orders', async (req, res) => {
  const { customer_name, product_id, quantity, total_price } = req.body;
  try {
    // Validar producto
    const productRes = await axios.get(`${PRODUCTS_SERVICE}/api/products/${product_id}`);
    if (!productRes.data) {
      return res.status(404).json({ error: 'Product not found' });
    }

    const connection = await pool.getConnection();
    const [result] = await connection.query(
      'INSERT INTO orders (customer_name, product_id, quantity, total_price) VALUES (?, ?, ?, ?)',
      [customer_name, product_id, quantity, total_price]
    );
    connection.release();
    res.status(201).json({ id: result.insertId, ...req.body });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to create order' });
  }
});

// Update order
app.put('/api/orders/:id', async (req, res) => {
  const { customer_name, product_id, quantity, total_price } = req.body;
  try {
    const connection = await pool.getConnection();
    await connection.query(
      'UPDATE orders SET customer_name = ?, product_id = ?, quantity = ?, total_price = ? WHERE id = ?',
      [customer_name, product_id, quantity, total_price, req.params.id]
    );
    connection.release();
    res.json({ id: req.params.id, ...req.body });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to update order' });
  }
});

// Delete order
app.delete('/api/orders/:id', async (req, res) => {
  try {
    const connection = await pool.getConnection();
    await connection.query('DELETE FROM orders WHERE id = ?', [req.params.id]);
    connection.release();
    res.json({ message: 'Order deleted' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to delete order' });
  }
});

// Iniciar servidor
app.listen(PORT, async () => {
  await initDatabase();
  console.log(`Orders service running on port ${PORT}`);
});

module.exports = app;
