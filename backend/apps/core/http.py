import uuid

from django.core.files.uploadhandler import FileUploadHandler, StopUpload
from django.http import JsonResponse


class VisionUploadLimit(FileUploadHandler):
    def __init__(self, request):
        super().__init__(request)
        self.total = 0

    def receive_data_chunk(self, raw_data, start):
        from apps.vision.images import MAX_BATCH_BYTES, MAX_IMAGE_BYTES

        size = len(raw_data)
        self.total += size
        if start + size > MAX_IMAGE_BYTES or self.total > MAX_BATCH_BYTES:
            self.request.vision_upload_too_large = True
            raise StopUpload(connection_reset=True)
        return raw_data

    def file_complete(self, file_size):
        return None


def api_headers(get_response):
    def middleware(request):
        from apps.vision.images import MAX_BATCH_BYTES

        if not request.path_info.startswith("/api/v1/"):
            return get_response(request)
        request.api_request_id = str(uuid.uuid4())
        if request.path_info == "/api/v1/oracle/transcribe/":
            from django.conf import settings

            try:
                size = int(request.META.get("CONTENT_LENGTH") or 0)
            except ValueError:
                size = 0
            if size > settings.STT_MAX_UPLOAD_BYTES + 256 * 1024:
                return JsonResponse({
                    "code": "request_too_large", "detail": "Audio upload exceeds the maximum size.",
                    "requestId": request.api_request_id,
                }, status=413, headers={"X-Request-ID": request.api_request_id, "Cache-Control": "no-store"})
        if request.path_info in {"/api/v1/vision/recognize/", "/api/v1/vision/recognize-batch/"}:
            try:
                size = int(request.META.get("CONTENT_LENGTH") or 0)
            except ValueError:
                size = 0
            if size > MAX_BATCH_BYTES + 1024 * 1024:
                return JsonResponse({
                    "code": "request_too_large", "detail": "Request exceeds the upload limit.",
                    "requestId": request.api_request_id,
                }, status=413, headers={"X-Request-ID": request.api_request_id, "Cache-Control": "no-store"})
            request.upload_handlers.insert(0, VisionUploadLimit(request))
        response = get_response(request)
        response.headers.setdefault("X-Request-ID", request.api_request_id)
        response.headers.setdefault("Cache-Control", "no-store")
        return response

    return middleware
