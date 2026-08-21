// // import { useEffect, useState } from 'react';
// import {useState } from 'react';
// import { api } from './api';
// import Dashboard from './Dashboard';
// import Login from './Login';
// import Signup from './Signup';
// import Profile from './Profile';

// export default function App() {
//   //
//   const [token, setToken] = useState(() => localStorage.getItem('token'));

//   const [tab, setTab] = useState('catalog');
//   const [catalog, setCatalog] = useState([]);
//   const [error, setError] = useState(null);

//   useEffect(() => {
//     api.catalog().then(setCatalog).catch((err) => setError(err.message));
//   }, []);

//   return (
//     <div style={{ fontFamily: 'sans-serif', padding: '2rem' }}>
//       <h1>EventHub</h1>

//       <div style={{ marginBottom: '1rem' }}>
//         <button onClick={() => setTab('catalog')} disabled={tab === 'catalog'}>
//           Catalog
//         </button>{' '}
//         <button onClick={() => setTab('dashboard')} disabled={tab === 'dashboard'}>
//           Dashboard
//         </button>
//       </div>

//       {tab === 'catalog' && (
//         <div>
//           {error && <p style={{ color: 'crimson' }}>Failed to load catalog: {error}</p>}
//           <ul>
//             {catalog.map((event) => (
//               <li key={event.id}>
//                 {event.title} - ${event.price}
//               </li>
//             ))}
//           </ul>
//         </div>
//       )}

//       {tab === 'dashboard' && <Dashboard />}
//     </div>
//   );
// }
import { useState } from 'react';
import Login from './Login';
import Signup from './Signup';
import Profile from './Profile';
import Dashboard from './Dashboard';
import ReviewForm from './ReviewForm';
import { api } from './api';

export default function App() {
  const [token, setToken] = useState(
    () => localStorage.getItem('token')
  );

  const [screen, setScreen] = useState('catalog');
  const [events, setEvents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  async function loadCatalog() {
    setLoading(true);
    setError('');

    try {
      const data = await api.catalog();
      setEvents(Array.isArray(data) ? data : []);
    } catch (err) {
      setError(err.message || 'Failed to load catalog');
    } finally {
      setLoading(false);
    }
  }

  function handleLogin() {
    setToken(localStorage.getItem('token'));
    setScreen('catalog');
    loadCatalog();
  }

  function handleLogout() {
    setToken(null);
    setScreen('catalog');
  }

  if (!token) {
    if (screen === 'signup') {
      return (
        <Signup
          onGoToLogin={() => setScreen('login')}
        />
      );
    }

    return (
      <Login
        onLogin={handleLogin}
        onGoToSignup={() => setScreen('signup')}
      />
    );
  }

  return (
    <div>
      <nav className="navbar">
        <div className="nav-logo">EventHub</div>

        <div className="nav-links">
          <button
            className={`nav-button ${
              screen === 'catalog' ? 'active' : ''
            }`}
            onClick={() => {
              setScreen('catalog');
              loadCatalog();
            }}
          >
            Events
          </button>

          <button
            className={`nav-button ${
              screen === 'dashboard' ? 'active' : ''
            }`}
            onClick={() => setScreen('dashboard')}
          >
            Dashboard
          </button>

          <button
            className={`nav-button ${
              screen === 'profile' ? 'active' : ''
            }`}
            onClick={() => setScreen('profile')}
          >
            Profile
          </button>

          <button
            className="nav-button"
            onClick={handleLogout}
          >
            Logout
          </button>
        </div>
      </nav>

      {screen === 'catalog' && (
        <main style={{ padding: '40px' }}>
          <h1>Upcoming Events</h1>
          <p style={{ color: '#6b7280' }}>
            Discover and book your next event.
          </p>

          {loading && <p>Loading events...</p>}

          {error && <div className="error">{error}</div>}

          {!loading && !error && (
            <div
              style={{
                display: 'grid',
                gridTemplateColumns:
                  'repeat(auto-fill, minmax(250px, 1fr))',
                gap: '20px',
                marginTop: '30px',
              }}
            >
              {events.map((event) => (
                <div
                  key={event.id}
                  style={{
                    background: 'white',
                    padding: '25px',
                    borderRadius: '15px',
                    boxShadow:
                      '0 5px 20px rgba(0,0,0,0.06)',
                  }}
                >
                  <h2>{event.title}</h2>

                  <p
                    style={{
                      color: '#6b7280',
                      marginBottom: '20px',
                    }}
                  >
                    Event #{event.id}
                  </p>

                  <strong>${event.price}</strong>

                  <button
                    className="primary-button"
                    style={{ width: '100%' }}

                    onClick={async () => {
                      try {
                        const token = localStorage.getItem('token');

                        if (!token) {
                          throw new Error('You must be logged in.');
                        }

                        const payload = JSON.parse(atob(token.split('.')[1]));

                        const userId = String(payload.sub);

                        if (!userId || userId === 'undefined') {
                          throw new Error('Could not determine your user ID.');
                        }

                        const booking = await api.book(userId, event.id);

                        alert(
                          `Booking confirmed!\nBooking ID: ${booking.id}`
                        );
                      } catch (err) {
                        alert(err.message || 'Booking failed');
                      }
                    }}
                  >
                    Book Now
                  </button>
                </div>
              ))}
            </div>
          )}
        </main>
      )}

      {screen === 'dashboard' && <Dashboard />}

      {screen === 'profile' && (
        <Profile onLogout={handleLogout} />
      )}
    </div>
  );
}