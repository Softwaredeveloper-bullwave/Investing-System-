from django.core.management.base import BaseCommand



from stocks.market_data_service import get_market_snapshot

from stocks.quote_provider import FinnhubError





class Command(BaseCommand):

    help = 'Refresh live stock quotes and indices (Alpha Vantage / Finnhub / Yahoo)'



    def handle(self, *args, **options):

        try:

            snapshot = get_market_snapshot()

        except FinnhubError as exc:

            self.stderr.write(self.style.ERROR(str(exc)))

            return



        self.stdout.write(

            self.style.SUCCESS(

                f"Provider: {snapshot['provider']} — updated {len(snapshot['stocks'])} stocks and "

                f"{len(snapshot['indices'])} indices at {snapshot['updated_at']}"

            )

        )

        for stock in snapshot['stocks'][:5]:

            self.stdout.write(f"  {stock.symbol}: ₹{stock.ltp} ({stock.change_percent:+.2f}%)")

