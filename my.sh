find . -type f -name "*.mdx" -exec bash -c 'for f; do mv "$f" "${f%.mdx}.md"; done' _ {} +
echo "Done"