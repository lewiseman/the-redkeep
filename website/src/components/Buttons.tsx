import { APK, LINKS } from '../site';

export function DownloadButton() {
  return <a className="btn btn--primary" href={LINKS.apk} aria-label={`Download Redkeep ${APK.version} APK, ${APK.size}. ${APK.requirements}`} title={`Redkeep ${APK.version} · ${APK.size} · ${APK.requirements}`}>Download APK</a>;
}
