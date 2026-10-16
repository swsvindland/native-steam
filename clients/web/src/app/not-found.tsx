import Link from "next/link";

export default function NotFound() {
  return (
    <div className="page page--store">
      <div className="page__inner page__inner--store not-found">
        <h1>Page not found</h1>
        <p>That page isn’t part of this concept.</p>
        <Link href="/store/" className="btn btn--install" data-autofocus>
          Back to the Store
        </Link>
      </div>
    </div>
  );
}
