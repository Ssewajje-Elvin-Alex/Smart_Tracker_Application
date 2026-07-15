from rest_framework import generics
from .models import TrackerData
from  .serializers import TrackerDataSerializer

# ESP 32 sends GPS data data here
class TrackerDataCreateView(generics.CreateAPIView):
    queryset= TrackerData.objects.all()
    serializer_class=TrackerDataSerializer

#flutter gets lastest Gps data here
class LatestTrackerDataView(generics.RetrieveAPIView):
    queryset= TrackerData.objects.all()
    serializer_class=TrackerDataSerializer

    def get_object(self):
        return TrackerData.objects.order_by('timestamp').last()
