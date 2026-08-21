import { useState } from 'react';
import { api } from './api';

export default function ReviewForm({
  bookingId,
  onSubmitted,
}) {
  const [text, setText] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e) {
    e.preventDefault();

    if (!text.trim()) {
      setError('Please write a review.');
      return;
    }

    try {
      setLoading(true);
      setError('');

      const review = await api.submitReview(
        bookingId,
        text.trim()
      );

      console.log('Review submitted:', review);

      setText('');

      if (onSubmitted) {
        onSubmitted(review);
      }
    } catch (err) {
      setError(
        err.message || 'Failed to submit review'
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <form
      className="review-form"
      onSubmit={handleSubmit}
    >
      <label>Write a review</label>

      <textarea
        value={text}
        onChange={(e) => setText(e.target.value)}
        placeholder="How was your experience?"
        rows={4}
      />

      {error && (
        <div className="error">
          {error}
        </div>
      )}

      <button
        type="submit"
        className="primary-button"
        disabled={loading}
      >
        {loading ? 'Analyzing...' : 'Submit Review'}
      </button>
    </form>
  );
}

