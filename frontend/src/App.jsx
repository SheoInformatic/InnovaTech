import React, { useState, useEffect } from 'react'
import axios from 'axios'
import './App.css'

const API_PRODUCTS = 'http://a60717bab057a494e85e31614436ec10-2117845323.us-east-1.elb.amazonaws.com/api/products'
const API_ORDERS = 'http://a0882ac85b088436d98569fbc4e9eb03-501305419.us-east-1.elb.amazonaws.com/api/orders'

function App() {
  const [products, setProducts] = useState([])
  const [orders, setOrders] = useState([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [activeTab, setActiveTab] = useState('products')
  const [editingProduct, setEditingProduct] = useState(null)

  const [form, setForm] = useState({
    name: '',
    description: '',
    price: '',
    stock: '',
    platform: ''
  })

  useEffect(() => {
    fetchProducts()
  }, [])

  const cleanMessages = () => {
    setError('')
    setSuccess('')
  }

  const fetchProducts = async () => {
    setLoading(true)
    cleanMessages()
    try {
      const response = await axios.get(API_PRODUCTS)
      setProducts(response.data)
    } catch (err) {
      setError('Error al cargar productos: ' + err.message)
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const fetchOrders = async () => {
    setLoading(true)
    cleanMessages()
    try {
      const response = await axios.get(API_ORDERS)
      setOrders(response.data)
    } catch (err) {
      setError('Error al cargar órdenes: ' + err.message)
      console.error(err)
    } finally {
      setLoading(false)
    }
  }

  const handleTabChange = async (tab) => {
    setActiveTab(tab)
    cleanMessages()

    if (tab === 'products') {
      await fetchProducts()
    }

    if (tab === 'orders') {
      await fetchOrders()
    }
  }

  const handleInputChange = (event) => {
    const { name, value } = event.target

    setForm({
      ...form,
      [name]: value
    })
  }

  const resetForm = () => {
    setForm({
      name: '',
      description: '',
      price: '',
      stock: '',
      platform: ''
    })
    setEditingProduct(null)
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    cleanMessages()

    if (!form.name || !form.description || !form.price || !form.stock || !form.platform) {
      setError('Completa todos los campos antes de guardar.')
      return
    }

    const productData = {
      name: form.name,
      description: form.description,
      price: Number(form.price),
      stock: Number(form.stock),
      platform: form.platform
    }

    try {
      if (editingProduct) {
        await axios.put(`${API_PRODUCTS}/${editingProduct.id}`, productData)
        setSuccess('Producto actualizado correctamente.')
      } else {
        await axios.post(API_PRODUCTS, productData)
        setSuccess('Producto agregado correctamente.')
      }

      resetForm()
      await fetchProducts()
    } catch (err) {
      setError('Error al guardar producto: ' + err.message)
      console.error(err)
    }
  }

  const handleEdit = (product) => {
    cleanMessages()
    setEditingProduct(product)
    setForm({
      name: product.name,
      description: product.description,
      price: product.price,
      stock: product.stock,
      platform: product.platform
    })

    window.scrollTo({
      top: 0,
      behavior: 'smooth'
    })
  }

  const handleDelete = async (id) => {
    cleanMessages()

    const confirmDelete = window.confirm('¿Seguro que deseas eliminar este producto?')

    if (!confirmDelete) {
      return
    }

    try {
      await axios.delete(`${API_PRODUCTS}/${id}`)
      setSuccess('Producto eliminado correctamente.')
      await fetchProducts()
    } catch (err) {
      setError('Error al eliminar producto: ' + err.message)
      console.error(err)
    }
  }

  const increaseStock = async (product) => {
    cleanMessages()

    try {
      const updatedProduct = {
        ...product,
        stock: Number(product.stock) + 1,
        price: Number(product.price)
      }

      await axios.put(`${API_PRODUCTS}/${product.id}`, updatedProduct)
      setSuccess(`Stock aumentado para ${product.name}.`)
      await fetchProducts()
    } catch (err) {
      setError('Error al aumentar stock: ' + err.message)
      console.error(err)
    }
  }

  const decreaseStock = async (product) => {
    cleanMessages()

    if (Number(product.stock) <= 0) {
      setError('No se puede disminuir más el stock.')
      return
    }

    try {
      const updatedProduct = {
        ...product,
        stock: Number(product.stock) - 1,
        price: Number(product.price)
      }

      await axios.put(`${API_PRODUCTS}/${product.id}`, updatedProduct)
      setSuccess(`Stock disminuido para ${product.name}.`)
      await fetchProducts()
    } catch (err) {
      setError('Error al disminuir stock: ' + err.message)
      console.error(err)
    }
  }

  return (
    <div className="app">
      <header className="header">
        <h1>🎮 Inovatech Gaming Store</h1>
        <p>Tu tienda de juegos en la nube</p>
      </header>

      {error && <div className="error">{error}</div>}
      {success && <div className="success">{success}</div>}

      <nav className="tabs">
        <button
          className={`tab ${activeTab === 'products' ? 'active' : ''}`}
          onClick={() => handleTabChange('products')}
        >
          Productos
        </button>
        <button
          className={`tab ${activeTab === 'orders' ? 'active' : ''}`}
          onClick={() => handleTabChange('orders')}
        >
          Órdenes
        </button>
      </nav>

      <main className="content">
        {activeTab === 'products' && (
          <>
            <section className="admin-panel">
              <h2>{editingProduct ? 'Editar producto' : 'Agregar producto'}</h2>

              <form className="product-form" onSubmit={handleSubmit}>
                <input
                  type="text"
                  name="name"
                  placeholder="Nombre"
                  value={form.name}
                  onChange={handleInputChange}
                />

                <input
                  type="text"
                  name="description"
                  placeholder="Descripción"
                  value={form.description}
                  onChange={handleInputChange}
                />

                <input
                  type="number"
                  name="price"
                  placeholder="Precio"
                  value={form.price}
                  onChange={handleInputChange}
                  min="0"
                />

                <input
                  type="number"
                  name="stock"
                  placeholder="Stock"
                  value={form.stock}
                  onChange={handleInputChange}
                  min="0"
                />

                <select name="platform" value={form.platform} onChange={handleInputChange}>
                  <option value="">Selecciona plataforma</option>
                  <option value="PC">PC</option>
                  <option value="PlayStation">PlayStation</option>
                  <option value="Nintendo">Nintendo</option>
                  <option value="Xbox">Xbox</option>
                </select>

                <div className="form-actions">
                  <button type="submit" className="btn btn-primary">
                    {editingProduct ? 'Actualizar producto' : 'Agregar producto'}
                  </button>

                  {editingProduct && (
                    <button type="button" className="btn btn-secondary" onClick={resetForm}>
                      Cancelar edición
                    </button>
                  )}
                </div>
              </form>
            </section>

            {loading && <div className="loading">Cargando...</div>}

            {!loading && (
              <div className="products-grid">
                {products.length === 0 ? (
                  <p>No hay productos disponibles</p>
                ) : (
                  products.map((product) => (
                    <div key={product.id} className="product-card">
                      <h3>{product.name}</h3>
                      <p className="platform">{product.platform}</p>
                      <p className="description">{product.description}</p>

                      <div className="product-info">
                        <span className="price">${product.price}</span>
                        <span className="stock">Stock: {product.stock}</span>
                      </div>

                      <div className="stock-actions">
                        <button className="btn btn-stock" onClick={() => decreaseStock(product)}>
                          - Stock
                        </button>
                        <button className="btn btn-stock" onClick={() => increaseStock(product)}>
                          + Stock
                        </button>
                      </div>

                      <div className="card-actions">
                        <button className="btn btn-edit" onClick={() => handleEdit(product)}>
                          Editar
                        </button>
                        <button className="btn btn-delete" onClick={() => handleDelete(product.id)}>
                          Eliminar
                        </button>
                      </div>
                    </div>
                  ))
                )}
              </div>
            )}
          </>
        )}

        {activeTab === 'orders' && (
          <>
            {loading && <div className="loading">Cargando...</div>}

            {!loading && (
              <div className="orders-table">
                {orders.length === 0 ? (
                  <p>No hay órdenes disponibles</p>
                ) : (
                  <table>
                    <thead>
                      <tr>
                        <th>ID</th>
                        <th>Cliente</th>
                        <th>Producto ID</th>
                        <th>Cantidad</th>
                        <th>Total</th>
                        <th>Estado</th>
                      </tr>
                    </thead>
                    <tbody>
                      {orders.map((order) => (
                        <tr key={order.id}>
                          <td>{order.id}</td>
                          <td>{order.customer_name}</td>
                          <td>{order.product_id}</td>
                          <td>{order.quantity}</td>
                          <td>${order.total_price}</td>
                          <td>
                            <span className={`status ${order.status}`}>{order.status}</span>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
              </div>
            )}
          </>
        )}
      </main>
    </div>
  )
}

export default App
