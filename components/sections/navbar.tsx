import Image from "next/image";
import Link from "next/link";
import { ModeToggle } from "../theme-toggle";
import { buttonVariants } from "../ui/button";
import { cn } from "@/lib/utils";

const Navbar = () => {

  return (
    <header className="fixed w-full md:w-11/12 top-0 md:top-2 z-40 border-b border-border/50 bg-background/60 backdrop-blur-xl md:rounded-full -translate-x-1/2 left-1/2">
      <div className="mx-auto flex h-15 w-full max-w-8xl items-center justify-between px-2 sm:px-6 lg:px-8 rounded-full">
        <Link
          href="/"
          className="flex items-center gap-2"
          aria-label="Rivora home"
        >
          <Image
            src="/rivora-logo.svg"
            alt="Rivora logo"
            width={32}
            height={32}
            unoptimized
            className="size-7 sm:size-8 transition-transform duration-300 hover:scale-105"
          />
          <span className="text-sm md:text-lg font-bold tracking-tight text-foreground">
            Rivora
          </span>
        </Link>

        <div className="flex items-center gap-1 md:gap-3">
          <ModeToggle />
          <Link
            href="/login"
            className={cn(
              buttonVariants({ variant: "glow" }),
              "rounded-full h-10",
            )}
          >
            Get started
          </Link>
        </div>
      </div>
    </header>
  );
};

export default Navbar;
