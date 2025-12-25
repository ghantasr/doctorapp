# Web Deployment Guide

## Overview

The web application provides a unified portal where users can choose between Doctor Portal and Patient Portal from a single landing page.

## Features

- **Unified Portal**: Single web application for both doctors and patients
- **Portal Selection**: Beautiful landing page with portal cards
- **Responsive Design**: Works on desktop, tablet, and mobile browsers
- **PWA Support**: Can be installed as a Progressive Web App
- **Dynamic Routing**: Separate routes for `/doctor/login` and `/patient/login`

## Local Development

### Run the web app locally
```bash
flutter run -d chrome
```

### Run on specific port
```bash
flutter run -d chrome --web-port=8080
```

### Run with hot reload
```bash
flutter run -d chrome --hot
```

## Building for Production

### Standard build
```bash
flutter build web --release
```

### Build with optimizations
```bash
flutter build web --release --web-renderer html
```

Or for better performance on modern browsers:
```bash
flutter build web --release --web-renderer canvaskit
```

### Build for subdirectory deployment
If deploying to a subdirectory (e.g., `https://example.com/healthcare/`):
```bash
flutter build web --release --base-href /healthcare/
```

## Deployment Options

### 1. Firebase Hosting

**Setup:**
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
```

**Deploy:**
```bash
flutter build web --release
firebase deploy --only hosting
```

**firebase.json example:**
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### 2. Netlify

**Option A: Drag and Drop**
1. Build: `flutter build web --release`
2. Go to [Netlify](https://app.netlify.com)
3. Drag `build/web` folder to dashboard

**Option B: CLI**
```bash
npm install -g netlify-cli
netlify login
flutter build web --release
netlify deploy --prod --dir=build/web
```

**netlify.toml example:**
```toml
[build]
  publish = "build/web"
  command = "flutter build web --release"

[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```

### 3. Vercel

```bash
npm install -g vercel
flutter build web --release
vercel --prod build/web
```

**vercel.json example:**
```json
{
  "routes": [
    {
      "handle": "filesystem"
    },
    {
      "src": "/(.*)",
      "dest": "/index.html"
    }
  ]
}
```

### 4. GitHub Pages

**Setup:**
1. Build: `flutter build web --release --base-href /<repository-name>/`
2. Copy `build/web` contents to a `docs` folder or `gh-pages` branch
3. Enable GitHub Pages in repository settings

**Using gh-pages branch:**
```bash
flutter build web --release --base-href /<repository-name>/
cd build/web
git init
git add .
git commit -m "Deploy"
git branch -M gh-pages
git remote add origin https://github.com/username/repository.git
git push -f origin gh-pages
```

### 5. AWS S3 + CloudFront

**S3 Bucket Setup:**
1. Create S3 bucket
2. Enable static website hosting
3. Upload `build/web` contents
4. Set bucket policy for public read

**Deploy:**
```bash
flutter build web --release
aws s3 sync build/web s3://your-bucket-name --delete
```

**With CloudFront:**
```bash
aws cloudfront create-invalidation --distribution-id YOUR_DIST_ID --paths "/*"
```

### 6. Docker Deployment

**Dockerfile example:**
```dockerfile
FROM nginx:alpine

# Copy built web app
COPY build/web /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**nginx.conf example:**
```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

**Build and run:**
```bash
flutter build web --release
docker build -t healthcare-web .
docker run -p 8080:80 healthcare-web
```

## Environment Variables

For production deployment, update `.env` file or use environment variables:

```bash
SUPABASE_URL=your_production_supabase_url
SUPABASE_ANON_KEY=your_production_anon_key
```

## Performance Optimization

### 1. Enable caching
Add cache headers in your web server configuration.

### 2. Compress assets
Most hosting platforms handle this automatically, but ensure gzip/brotli compression is enabled.

### 3. CDN
Use a CDN for faster global delivery:
- Firebase Hosting (built-in CDN)
- CloudFront (AWS)
- Cloudflare

### 4. Optimize images
Ensure tenant logos and icons are optimized (WebP format recommended).

## Custom Domain

### Firebase Hosting
```bash
firebase hosting:channel:deploy custom-domain
```

### Netlify
Add custom domain in Netlify dashboard under Domain Settings.

### Vercel
```bash
vercel domains add yourdomain.com
```

## SSL/HTTPS

All modern hosting platforms provide free SSL certificates:
- Firebase Hosting: Automatic
- Netlify: Automatic
- Vercel: Automatic
- AWS: Use AWS Certificate Manager

## Monitoring

### Add analytics

**Google Analytics:**
Add to `web/index.html`:
```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</script>
```

### Error tracking

Use services like:
- Sentry
- Firebase Crashlytics (web)
- Bugsnag

## Testing

### Test locally before deployment
```bash
# Build
flutter build web --release

# Serve locally
cd build/web
python -m http.server 8000
# Or
npx http-server -p 8000
```

Visit: `http://localhost:8000`

## Troubleshooting

### Issue: Blank page after deployment
- Check browser console for errors
- Verify base-href is correct
- Ensure all routes are configured with fallback to index.html

### Issue: Environment variables not working
- Rebuild the app after changing `.env`
- Verify `.env` is in the correct location

### Issue: 404 on refresh
- Configure server to redirect all routes to `index.html`
- Add appropriate rewrites in hosting configuration

## Security Checklist

- [ ] Use HTTPS only
- [ ] Set proper CORS headers in Supabase
- [ ] Enable Content Security Policy (CSP)
- [ ] Keep dependencies updated
- [ ] Use environment variables for sensitive data
- [ ] Enable rate limiting if possible
- [ ] Monitor for suspicious activity

## Resources

- [Flutter Web Documentation](https://flutter.dev/web)
- [Firebase Hosting Guide](https://firebase.google.com/docs/hosting)
- [Netlify Documentation](https://docs.netlify.com)
- [Vercel Documentation](https://vercel.com/docs)
