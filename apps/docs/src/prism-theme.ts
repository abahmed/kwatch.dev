import type {PrismTheme} from 'prism-react-renderer';

// Code theme built from the brand tokens (light and dark follow the system).
// Colour is neutral; status colours appear only for diff add and remove.
export const kwatchPrismTheme: PrismTheme = {
  plain: {color: 'var(--text)', backgroundColor: 'var(--surface)'},
  styles: [
    {types: ['comment', 'prolog', 'doctype', 'cdata'], style: {color: 'var(--text-muted)', fontStyle: 'italic'}},
    {types: ['punctuation', 'operator'], style: {color: 'var(--text-muted)'}},
    {types: ['keyword', 'tag', 'selector', 'important', 'atrule'], style: {color: 'var(--text)', fontWeight: '700'}},
    {types: ['string', 'attr-value', 'char', 'url'], style: {color: 'var(--text-soft)'}},
    {types: ['number', 'boolean', 'constant', 'symbol'], style: {color: 'var(--text-soft)'}},
    {types: ['function', 'class-name', 'attr-name', 'property'], style: {color: 'var(--text)'}},
    {types: ['inserted'], style: {color: 'var(--success)', backgroundColor: 'var(--success-bg)'}},
    {types: ['deleted'], style: {color: 'var(--failing)', backgroundColor: 'var(--failing-bg)'}},
  ],
};
