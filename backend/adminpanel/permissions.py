from rest_framework.permissions import BasePermission


class IsAdminStaff(BasePermission):
    """Only staff/superuser accounts may use the admin panel API.

    Deliberately separate from DRF's built-in IsAdminUser so the admin-panel
    surface has one obvious, auditable gate rather than relying on a
    framework default that could silently change behaviour.
    """

    message = 'You do not have permission to access the admin panel.'

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and (user.is_staff or user.is_superuser))
