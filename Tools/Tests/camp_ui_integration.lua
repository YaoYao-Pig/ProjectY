-- Native camp UI regression entry. The dedicated Edit Mode host supplies isolated callbacks.
assert(AttachCampPreview and CaptureCamp and ClickCamp and DragCamp and CampWorldCamera,
    'Run Tools/CampRework/render_preview.cs through the existing idle Unity MCP host')
return dofile('Tools/CampRework/preview.lua')