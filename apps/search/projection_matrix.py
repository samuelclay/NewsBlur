import os

import numpy as np

PROJECTION_MATRIX_PATH = os.path.join(os.path.dirname(__file__), "random_projection_matrix.npy")
INPUT_DIMS = 1536
OUTPUT_DIMS = 256


def generate_projection_matrix():
    """Generate a random projection matrix for dimensionality reduction."""
    # Use a fixed random seed for reproducibility
    np.random.seed(42)

    # Generate random matrix
    projection = np.random.normal(0, 1 / np.sqrt(OUTPUT_DIMS), (OUTPUT_DIMS, INPUT_DIMS))

    # Normalize the matrix
    projection = projection / np.linalg.norm(projection, axis=1)[:, np.newaxis]

    return projection


def get_projection_matrix():
    """Get the projection matrix, generating it if it doesn't exist."""
    if not os.path.exists(PROJECTION_MATRIX_PATH):
        projection = generate_projection_matrix()
        np.save(PROJECTION_MATRIX_PATH, projection)
    return np.load(PROJECTION_MATRIX_PATH)


def project_vector(vector):
    """Project a vector from 1536 dimensions to 256 dimensions."""
    projection = get_projection_matrix()
    projected = np.dot(projection, vector)
    # Normalize the projected vector
    return projected / np.linalg.norm(projected)
