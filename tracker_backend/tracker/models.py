from django.db import models

# Create your models here.

class TrackerData(models.Model):
    latitude = models.FloatField()
    longitude = models.FloatField()
    emergency=models.BooleanField(default=False)
    battery_level=models.IntegerField(default=100)
    timestamp=models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"Location: ({self.latitude},{self.longitude})"
