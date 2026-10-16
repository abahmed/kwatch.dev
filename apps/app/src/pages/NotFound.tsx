import {Link} from 'react-router-dom';
import {Card, usePageTitle} from '../components';

export default function NotFound() {
  usePageTitle('Page not found');
  return (
    <Card>
      <p className="eyebrow">404</p>
      <h1>Page not found</h1>
      <p className="lead">That page does not exist.</p>
      <p className="body">
        <Link to="/licenses">Go to your licenses</Link>
      </p>
    </Card>
  );
}
