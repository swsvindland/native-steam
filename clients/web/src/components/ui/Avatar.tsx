import { Art } from "./Art";

/** Square Steam avatar with a status-coloured border. */
export function Avatar({
  src,
  status,
  size = 40,
  name,
  className = "",
}: {
  src: string;
  status?: string;
  size?: number;
  name?: string;
  className?: string;
}) {
  return (
    <span
      className={`avatar avatar--${status ?? "none"} ${className}`}
      style={{ width: size, height: size }}
      title={name}
    >
      <Art src={src} label={name ? name.slice(0, 1).toUpperCase() : undefined} />
    </span>
  );
}
