const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Categories for books (same as in your app)
const categories = [
  "Best Selling Books",
  "Trending Books",
  "New Arrivals",
  "Editor's Picks",
  "Horror",
  "Comics",
  "History",
];

// Function to fetch books from Open Library API
async function fetchBooks(query, limit = 50) {
  try {
    const response = await axios.get(
      `https://openlibrary.org/search.json?q=${encodeURIComponent(query)}&fields=key,title,author_name,cover_i,first_publish_year&limit=${limit}`
    );
    return response.data.docs || [];
  } catch (error) {
    console.error('Error fetching books from Open Library API:', error.message);
    return [];
  }
}

// Function to generate a random price between $5 and $50
function getRandomPrice() {
  return (Math.random() * (50 - 5) + 5).toFixed(2); // Random price between 5 and 50
}

// Function to get a random category
function getRandomCategory() {
  return categories[Math.floor(Math.random() * categories.length)];
}

// Function to get random availability (true or false)
function getRandomAvailability() {
  return Math.random() > 0.2; // 80% chance of being available
}

// Function to populate Firestore with books
async function populateBooks() {
  // Define search queries to fetch different types of books
  const searchQueries = [
    'horror',            // Fetch horror books
    'comics',            // Fetch comics
    'history',           // Fetch history books
    'best selling',      // Fetch best-selling books
    'trending books',    // Fetch trending books
    'new releases',      // Fetch new arrivals
    'editors picks',     // Fetch editor's picks
    'stephen king',      // Fetch books by Stephen King
    'j.k. rowling',      // Fetch books by J.K. Rowling
    'graphic novels',    // Fetch graphic novels
  ];

  const booksRef = db.collection('books');
  let totalBooksAdded = 0;

  for (const query of searchQueries) {
    console.log(`Fetching books for query: "${query}"...`);
    const books = await fetchBooks(query, 50); // Fetch up to 50 books per query

    for (const book of books) {
      // Sanitize the book ID (e.g., /works/OL123W -> OL123W)
      const bookId = book.key.split('/').pop();

      // Check if the book already exists in Firestore to avoid duplicates
      const docRef = booksRef.doc(bookId);
      const doc = await docRef.get();
      if (doc.exists) {
        console.log(`Book "${book.title}" (${bookId}) already exists, skipping...`);
        continue;
      }

      // Prepare book data
      const bookData = {
        id: bookId,
        title: book.title || 'Unknown Title',
        author: book.author_name && book.author_name.length > 0 ? book.author_name[0] : 'Unknown Author',
        price: parseFloat(getRandomPrice()),
        availability: getRandomAvailability(),
        cover_id: book.cover_i ? book.cover_i.toString() : null,
        category: getRandomCategory(),
        first_publish_year: book.first_publish_year || 0,
        mockPopularity: Math.floor(Math.random() * 1000), // Random popularity for sorting
      };

      // Add book to Firestore
      try {
        await docRef.set(bookData);
        console.log(`Added book: "${bookData.title}" (${bookId})`);
        totalBooksAdded++;
      } catch (error) {
        console.error(`Error adding book "${bookData.title}" (${bookId}):`, error.message);
      }
    }
  }

  console.log(`Total books added: ${totalBooksAdded}`);
}

// Run the script
populateBooks()
  .then(() => {
    console.log('Population complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Population failed:', error);
    process.exit(1);
  });