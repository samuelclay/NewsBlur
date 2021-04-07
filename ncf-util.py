import pandas as pd
import numpy as np
import tensorflow as tf
import math
from pandas import DataFrame

def mask_first(x):
    """
    Return a list of 0 for the first item and 1 for all others
    """
    result = np.ones_like(x)
    result[0] = 0

    return result
