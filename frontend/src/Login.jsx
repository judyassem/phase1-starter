import { useState } from 'react';
import { api } from './api';

export default function Login({ onLogin, onGoToSignup }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();

    setError('');
    setLoading(true);

    try {
      const data = await api.login(email, password);

      // Your backend returns { token: "..." }
      localStorage.setItem('token', data.token);

      // Keep the email for the profile screen
      localStorage.setItem('userEmail', email);

      onLogin();
    } catch (err) {
      setError(err.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="auth-page">
      <div className="auth-card">
        <div className="logo">EventHub</div>

        <h1>Welcome back</h1>
        <p className="subtitle">Sign in to continue to EventHub</p>

        {error && <div className="error">{error}</div>}

        <form onSubmit={handleSubmit}>
          <label>Email</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="you@example.com"
            required
          />

          <label>Password</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Enter your password"
            required
          />

          <button className="primary-button" disabled={loading}>
            {loading ? 'Signing in...' : 'Login'}
          </button>
        </form>

        <p className="auth-switch">
          Don't have an account?{' '}
          <button className="link-button" onClick={onGoToSignup}>
            Sign up
          </button>
        </p>
      </div>
    </div>
  );
}