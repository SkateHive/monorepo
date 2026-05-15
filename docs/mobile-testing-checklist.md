# SkateHive Mobile Testing Checklist

## Critical Mobile Flows

### Authentication
- [ ] Login flow (all methods)
- [ ] Registration
- [ ] Password reset
- [ ] Session persistence
- [ ] Logout

### Content Browsing
- [ ] Feed loads correctly
- [ ] Infinite scroll works
- [ ] Pull-to-refresh
- [ ] Image/video loading
- [ ] Link previews

### User Interactions
- [ ] Like/upvote
- [ ] Comment submission
- [ ] Share functionality
- [ ] Profile viewing
- [ ] Follow/unfollow

### Media
- [ ] Photo upload (camera + gallery)
- [ ] Video upload and playback
- [ ] Image compression
- [ ] Progress indicators

### Navigation
- [ ] Bottom navigation
- [ ] Back button behavior
- [ ] Deep linking
- [ ] Notification navigation

### Performance
- [ ] Cold start < 3s
- [ ] Screen transitions smooth
- [ ] No memory leaks
- [ ] Offline behavior

### Responsive Design
- [ ] iPhone SE (small)
- [ ] iPhone 15 Pro (standard)
- [ ] iPad (tablet)
- [ ] Android various sizes

### Browser Testing
- [ ] Safari (iOS)
- [ ] Chrome (Android)
- [ ] Samsung Internet
- [ ] Firefox Mobile

## Regression Test Results Template

| Flow | Status | Notes |
|------|--------|-------|
| Auth - Login | ✅/❌ | |
| Feed - Load | ✅/❌ | |
| Feed - Scroll | ✅/❌ | |
| Media - Upload | ✅/❌ | |
