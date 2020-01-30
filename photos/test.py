import unittest

with open('functions.py') as infile:
    exec(infile.read())

class TestDms2dd(unittest.TestCase):
    def test(self):
        """
        Test that it can convert coordinates in degrees, minutes, seconds into decimal degrees
        """
        latitude_coords = [40, 45, 32]
        longitude_coords = [73, 58, 37]
        latitude_ref = 'N'
        longitude_ref = 'W'
        latitude = dms2dd(latitude_coords[0], latitude_coords[1], latitude_coords[2])
        if latitude_ref != 'N':
            latitude = 0 - latitude
        longitude = dms2dd(longitude_coords[0], longitude_coords[1], longitude_coords[2])
        if longitude_ref != 'E':
            longitude = 0 - longitude
        self.assertEqual(latitude, 40.75888888888889)
        self.assertEqual(longitude, -73.97694444444444)

if __name__ == '__main__':
    unittest.main()
