import { useEffect, useState } from 'react';
import { api } from './api';
import ReviewForm from './ReviewForm';

export default function Profile({ onLogout }) {
  const [email, setEmail] = useState('');
  const [userId, setUserId] = useState('');
  const [bookings, setBookings] = useState([]);
  const [reviews, setReviews] = useState({});
  const [loadingBookings, setLoadingBookings] = useState(true);
  const [error, setError] = useState('');
  const [reviewingBooking, setReviewingBooking] = useState(null);

  async function loadBookings() {
    try {
      setLoadingBookings(true);
      setError('');

      const token = localStorage.getItem('token');

      if (!token) {
        throw new Error('You are not logged in.');
      }

      const payload = JSON.parse(atob(token.split('.')[1]));
      const currentUserId = String(payload.sub);

      setUserId(currentUserId);

      const data = await api.bookings();

      const userBookings = data.filter(
        (booking) =>
          String(booking.userId) === currentUserId
      );

      setBookings(userBookings);
    } catch (err) {
      setError(
        err.message || 'Failed to load bookings'
      );
    } finally {
      setLoadingBookings(false);
    }
  }

  async function loadReviews() {
    try {
      const data = await api.reviews();

      const reviewsByBooking = {};

      data.forEach((review) => {
        reviewsByBooking[review.bookingId] = review;
      });

      setReviews(reviewsByBooking);
    } catch (err) {
      console.error('Failed to load reviews:', err);
    }
  }

  useEffect(() => {
    const storedEmail =
      localStorage.getItem('userEmail');

    setEmail(storedEmail || '');

    loadBookings();
    loadReviews();
  }, []);

  function handleReviewSubmitted(review) {
    setReviews((previous) => ({
      ...previous,
      [review.bookingId]: review,
    }));

    setReviewingBooking(null);
  }

  function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('userEmail');
    onLogout();
  }

  function getSentimentClass(sentiment) {
    if (!sentiment) {
      return '';
    }

    return String(sentiment).toLowerCase();
  }

  return (
    <div className="profile-page">
      <div className="profile-container">

        {/* Profile information */}
        <div className="profile-card">
          <div className="avatar">
            {email
              ? email.charAt(0).toUpperCase()
              : 'U'}
          </div>

          <h1>My Profile</h1>

          <p className="profile-subtitle">
            Your EventHub account
          </p>

          <div className="profile-info">
            <div className="info-row">
              <span>Email</span>
              <strong>{email}</strong>
            </div>

            <div className="info-row">
              <span>User ID</span>
              <strong>{userId}</strong>
            </div>

            <div className="info-row">
              <span>Account</span>
              <strong className="active-status">
                Active
              </strong>
            </div>
          </div>

          <button
            className="logout-button"
            onClick={logout}
          >
            Logout
          </button>
        </div>

        {/* Bookings */}
        <div className="bookings-section">
          <h2>My Bookings</h2>

          <p className="section-subtitle">
            Events you have booked.
          </p>

          {loadingBookings && (
            <p>Loading bookings...</p>
          )}

          {error && (
            <div className="error">
              {error}
            </div>
          )}

          {!loadingBookings &&
            !error &&
            bookings.length === 0 && (
              <div className="empty-state">
                You haven't booked any events yet.
              </div>
            )}

          {!loadingBookings &&
            bookings.map((booking) => {
              const review = reviews[booking.id];

              return (
                <div
                  className="booking-card"
                  key={booking.id}
                >
                  <div className="booking-info">
                    <div>
                      <h3>
                        Event # {booking.eventId}
                      </h3>
                    </div>

                    <span className="booking-status">
                      {booking.status}
                    </span>
                  </div>

                  <div className="booking-details">
                    <div>
                      <span>Booking ID: </span>
                      <strong>{booking.id}</strong>
                    </div>

                    <div>
                      <span>Booked on: </span>
                      <strong>
                        {new Date(
                          booking.createdAt
                        ).toLocaleDateString()}
                      </strong>
                    </div>
                  </div>

                  {/* Existing review */}
                  {review ? (
                    <div className="submitted-review">
                      <div className="review-title">
                        Your Review
                      </div>

                      <p className="submitted-review-text">
                        "{review.text}"
                      </p>

                      <div className="sentiment-result">
                        <div>
                          <span>
                            Sentiment
                          </span>

                          <strong
                            className={`sentiment-badge ${getSentimentClass(
                              review.sentiment
                            )}`}
                          >
                            {review.sentiment}
                          </strong>
                        </div>

                        {review.sentimentScore !==
                          undefined && (
                          <div>
                            <span>
                              Sentiment Score
                            </span>

                            <strong>
                              {Number(
                                review.sentimentScore
                              ).toFixed(2)}
                            </strong>
                          </div>
                        )}
                      </div>
                    </div>
                  ) : reviewingBooking ===
                    booking.id ? (
                    <div className="review-area">
                      <ReviewForm
                        bookingId={booking.id}
                        onSubmitted={
                          handleReviewSubmitted
                        }
                      />

                      <button
                        className="cancel-button"
                        onClick={() =>
                          setReviewingBooking(null)
                        }
                      >
                        Cancel
                      </button>
                    </div>
                  ) : (
                    <button
                      className="review-button"
                      onClick={() =>
                        setReviewingBooking(
                          booking.id
                        )
                      }
                    >
                      Write Review
                    </button>
                  )}
                </div>
              );
            })}
        </div>
      </div>
    </div>
  );
}



// import { useEffect, useState } from 'react';

// export default function Profile({ onLogout }) {
//   const [email, setEmail] = useState('');
//   const [userId, setUserId] = useState('');

//   useEffect(() => {
//     const storedEmail = localStorage.getItem('userEmail');
//     const token = localStorage.getItem('token');

//     setEmail(storedEmail || '');

//     if (token) {
//       try {
//         const payload = JSON.parse(atob(token.split('.')[1]));

//         if (payload.id) {
//           setUserId(String(payload.id));
//         } else if (payload.userId) {
//           setUserId(String(payload.userId));
//         } else if (payload.sub) {
//           setUserId(String(payload.sub));
//         }
//       } catch {
//         // Token is still usable for API requests.
//         // We just can't display its payload.
//       }
//     }
//   }, []);

//   function logout() {
//     localStorage.removeItem('token');
//     localStorage.removeItem('userEmail');
//     onLogout();
//   }

//   return (
//     <div className="profile-page">
//       <div className="profile-card">
//         <div className="avatar">
//           {email ? email.charAt(0).toUpperCase() : 'U'}
//         </div>

//         <h1>My Profile</h1>
//         <p className="profile-subtitle">Your EventHub account</p>

//         <div className="profile-info">
//           <div className="info-row">
//             <span>Email</span>
//             <strong>{email || 'Not available'}</strong>
//           </div>

//           <div className="info-row">
//             <span>User ID</span>
//             <strong>{userId || 'Not available'}</strong>
//           </div>

//           <div className="info-row">
//             <span>Account</span>
//             <strong>Active</strong>
//           </div>
//         </div>

//         <button className="logout-button" onClick={logout}>
//           Logout
//         </button>
//       </div>
//     </div>
//   );
// }