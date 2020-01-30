def dms2dd(degrees, minutes, seconds):
     dd = float(degrees) + float(minutes)/60 + float(seconds)/3600
     return dd
